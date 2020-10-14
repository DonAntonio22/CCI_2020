provider "exoscale" {
  key    = var.key
  secret = var.secret
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
// description = Beschreibung
variable "key" {
  description = "Enter exoscalse key"
}

variable "secret" {
  description = "Enter exoscalse secret"
}
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

export DEBIAN_FRONTEND=noninteractive

# region Install Docker
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

apt-key fingerprint 0EBFCD88
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
# endregion

# region Launch containers

# Run the load generator
docker run -d \
  --restart=always \
  -p 8080:8080 \
  janoszen/http-load-generator:1.0.1

# Run the node exporter
docker run -d \
  --restart=always \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  quay.io/prometheus/node-exporter \
  --path.rootfs=/host

# endregion

EOF

}

resource "exoscale_security_group" "sg" {
  name = "open-to-world"
}
//security group ist container mit einer liste von regeln über "exoscale_security_group_rule" werden die regeln erstellt
//ingress incoming pakete outgress outgoing pakete
resource "exoscale_security_group_rule" "http" {
  security_group_id = exoscale_security_group.sg.id
  type              = "INGRESS"
  protocol          = "tcp"
  cidr              = "0.0.0.0/0"
  start_port        = 80
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
