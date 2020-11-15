FROM python:latest
COPY servicediscovery.py /servicediscovery.py
COPY config.toml /
RUN mkdir /prometheus
RUN mkdir -p /srv/service-discovery
RUN chmod +x /servicediscovery.py
RUN pip install exoscale
CMD [ "python", "servicediscovery.py" ]