import os
import exoscale
import time
# Ein mapping Objekt, wird beim Ersten importieren von os gehalten.
#Änderungen werden nur genommen solange die direkt von os.environ kommen, Qulle: https://docs.python.org/3/library/os.html
os.environ["EXOSCALE_API_KEY"] = os.environ["EXOSCALE_KEY"]
os.environ["EXOSCALE_API_SECRET"] = os.environ["EXOSCALE_SECRET"]
ZONE = os.environ['EXOSCALE_ZONE']
INSTANCE_POOL = os.environ['EXOSCALE_INSTANCEPOOL_ID']

#Varibale für targets.json und targetPort
targets = "/prometheus/targets.json"
targetPort = os.environ['TARGET_PORT']
serviceDiscovery = "/srv/service-discovery/config.json"
#Platzhalter für Schlafe for in diesem Fall 22 Sekunden. Source:https://www.journaldev.com/15797/python-time-sleep
sleepForXSec = 22
while True:
        try:
                exoscale = exoscale.Exoscale()
                zone = exoscale.compute.get_zone(ZONE)
                instances = list(exoscale.compute.get_instance_pool(INSTANCE_POOL, zone).instances)

                # Format eines json-Files
                part1 = "[{\"targets\": [ "
                part2 = ""
                part3 = " ]}]"

                #Füge alle laufenden, up, Instanzen in die Liste ipAdresses ein
                ipAdresses = list()
                for oneInstance in instances:
                        if oneInstance.state == "running" :
                                ipAdresses.append("\""+oneInstance.ipv4_address+":"+str(targetPort)+"\"")

                # w öffnet ein File, in diesem Fall targets, zum Bearbeiten. Source: https://www.guru99.com/reading-and-writing-files-in-python.html
                #Änderungen am targets-File werden vorgenommen, es wird auf ihm geschrieben
                f = open(targets, "w")
                # Füge mehr Information, Daten in targets-File hinzu
                f.write(part1+(", ".join(ipAdresses))+part3)
                print(part1+(", ".join(ipAdresses))+part3)
                f.close()

                # Änderungen am serviceDiscovery-File werden vorgenommen, es wird auf ihm geschrieben
                f = open(serviceDiscovery, "w")
                f.write(part1+(", ".join(ipAdresses))+part3)
                f.close()
#Gleiche Ressource wie Zeile 13. https://www.journaldev.com/15797/python-time-sleep
#schlafe für 22 Sekunden
time.sleep(sleepForXSec)