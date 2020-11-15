provider "exoscale" {
  key = var.exoscale_key
  secret = var.exoscale_secret
}
# Variable secrion
//auf welchem server, welchem land es sich befindet
variable "zone" {
  default = "at-vie-1"
}
//welche OS wird verwendet
variable "template" {
  default = "Linux Ubuntu 20.04 LTS 64-bit"
}
variable "exoscale_key" {
  description = "Enter exoscalse key"
}
variable "exoscale_secret" {
  description = "Enter exoscalse secret"
}
// description = Beschreibung

// data definiert ein fertiges model, "exoscale_compute_template" ist die Type, Name der Ressource ist "ubuntu"
# Data section
data "exoscale_compute_template" "ubuntuVersion" {
  zone = "at-vie-1"
  name = "Linux Ubuntu 20.04 LTS 64-bit"
}


data "exoscale_compute_template" "instancepoolInfo" {
  zone = var.zone
  name = var.template
}
//ressource was terraform erstellt, statt auf weboberfläche alles auszuwählen, nimmt die erstellte ressource
# Rescource section
resource "exoscale_instance_pool" "instancepoolCreation" {
  name               = "name-for-instance-pool"
  description        = "empty discription"
  template_id        = data.exoscale_compute_template.instancepoolInfo.id
  service_offering   = "micro"
  size               = 3
  disk_size          = 10
  zone               = var.zone
  security_group_ids = [exoscale_security_group.sg.id]
  user_data = <<EOF
#!/bin/bash
set -e
#falls es neuere Pakete gibt hole sie dir
apt update
# installiert docker
curl -fsSL https://get.docker.com/ -o get-docker.sh
sudo sh get-docker.sh
# hole dir den http-load-generator
sudo docker pull janoszen/http-load-generator:latest
# wenn container 8080:8080 existiert lösche sie
sudo docker run -d --rm -p 8080:8080 janoszen/http-load-generator
# prometheus macht an sich nichts, node exporter (einfachste lösung) wird zum Lesen
# von Daten benötigt, wie zum Beispiel CPU und Speicher Nutzung
# Source: https://fh-cloud-computing.github.io/exercises/4-prometheus/
# führe container aus mit port 9100:9100
sudo docker run -d -p 9100:9100 \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  quay.io/prometheus/node-exporter \
  --path.rootfs=/host
EOF

}

resource "exoscale_security_group" "sg" {
  name = "open-to-world"
}
//security group ist container mit einer liste von regeln über "exoscale_security_group_rule" werden die regeln erstellt
//ingress incoming pakete outgress outgoing pakete
//start_port und end_port bleiben 8080 damit ich nicht eine ganze range für die security group verwende.
//start_port und end_port müssen auf 8080 sein damit auch der Request von websiteLoadBalancer durch die Firewall durch kann
resource "exoscale_security_group_rule" "http" {
  security_group_id = exoscale_security_group.sg.id
  type              = "INGRESS"
  protocol          = "tcp"
  cidr              = "0.0.0.0/0"
  start_port        = 8080
  end_port          = 8080
}

//load balancer wird erstellt "Einkaufszentrum erstellt"
resource "exoscale_nlb" "websiteLoadBalancer" {
  name        = "website-nlb"
  description = "empty discription"
  zone        = var.zone
}
//erstellt service am load balancer "Welche Geschäfte im Einkaufszentrum"
//port, welchem port er horchen soll. target_port, auf welchem port weiter leiten
resource "exoscale_nlb_service" "websiteService" {
  zone             = exoscale_nlb.websiteLoadBalancer.zone
  name             = "name-for-the-website"
  description      = "empty description"
  nlb_id           = exoscale_nlb.websiteLoadBalancer.id
  instance_pool_id = exoscale_instance_pool.instancepoolCreation.id
  protocol         = "tcp"
  port             = 80
  target_port      = 8080
  strategy         = "round-robin"

  // checkt seine gesundheit von load balancer services
  healthcheck {
    port     = 8080
    mode     = "http"
    uri      = "/health"
    interval = 5
    timeout  = 3
    retries  = 1
  }
}

#----------------------------------------------SPRINT 02----------------------------------------------------------------
// Änderungen schon im node-exporter vorgenommen Sprint 01
// es wird eine exoscale ressource über code anstatt über die weboberfläche
resource "exoscale_compute" "prometheus" {
  zone = var.zone
  display_name = "name-for-prometheus"
  template_id = data.exoscale_compute_template.ubuntuVersion.id
  size = "Micro"
  disk_size = 10
  key_pair = ""
  security_group_ids = [exoscale_security_group.sg.id]
  user_data = <<EOF
# Source: https://fh-cloud-computing.github.io/exercises/4-prometheus/
#!/bin/bash
set -e
#falls updates vorhanden sind installiere diese
sudo apt update
# installiere promotheus
sudo apt-get -y install prometheus
# Erstellt das configuration file für prometheus, dieses wird in prometheus.yml geschrieben
sudo echo "global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
  - job_name: Monitoring Server Node Exporter
    static_configs:
      - targets:
          - 'localhost:9100'
  - job_name: Service Discovery
    file_sd_configs:
      - files:
          - /etc/prometheus/targets.json
        refresh_interval: 10s" > /etc/prometheus/prometheus.yml;
# neustart des prometheus
sudo systemctl restart prometheus
# installiert docker
curl -fsSL https://get.docker.com/ -o get-docker.sh
sudo sh get-docker.sh
sudo docker pull donantonio22/service_discovery:latest
# ermöglicht das Ausführen von prometheus
# Erklärung der Variablen: https://docs.docker.com/engine/reference/run/
# -e setzt globale variable, -d startet container in detached mode,
#-v speicher/volume
sudo docker run \
    -d \
    -e EXOSCALE_KEY=${var.exoscale_key} \
    -e EXOSCALE_SECRET=${var.exoscale_secret} \
    -e EXOSCALE_ZONE=${var.zone} \
    -e EXOSCALE_INSTANCEPOOL_ID=${exoscale_instance_pool.instancepoolCreation.id} \
    -e TARGET_PORT=9100 \
    -v /etc/prometheus:/prometheus \
    donantonio22/service_discovery
EOF
}

//hier werden die Regeln für den container erstellt, hier für prometheus
resource "exoscale_security_group_rule" "prometheus" {
  security_group_id = exoscale_security_group.sg.id
  type = "INGRESS"
  protocol = "TCP"
  cidr = "0.0.0.0/0"
  start_port = 9090
  end_port = 9090
}
//hier werden die Reglen für container erstellt, hier für metrics_exporter
resource "exoscale_security_group_rule" "metrics_exporter" {
  security_group_id = exoscale_security_group.sg.id
  type = "INGRESS"
  protocol = "tcp"
  cidr = "0.0.0.0/0"
  start_port = 9100
  end_port = 9100
}
