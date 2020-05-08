SERVICE ?= host.docker.internal:18080
USR ?= tesla
PASSWORD ?= P4Sw0rD
NGINX_PORT ?= 9443

.PHONY: help
help:
	@echo "Environment variables"
	@echo ""
	@echo "SERVICE=$(SERVICE) service to expose."
	@echo "USR=$(USR) username to create."
	@echo "PASSWORD=$(PASSWORD) password for the user."
	@echo "NGINX_PORT=$(NGINX_PORT) local port to expose Nginx SSL and uthenticated version of the service."
	@echo ""
	@echo "NOTE: certificates are self-signed certificates"
	@echo ""
	@echo "usage:"
	@echo ""
	@echo "USR=$(USR) PASSWORD=$(PASSWORD) SERVICE=$(SERVICE) NGINX_PORT=$(NGINX_PORT) make start"
	@echo "make port-forward-ngrok"
	@echo ""
	@echo "Targets:"
	@echo ""
	@grep '^## @help' Makefile|cut -d ":" -f 2-3|( (sort|column -s ":" -t) || (sort|tr ":" "\t") || (tr ":" "\t"))

## @help:create-certificate:Create a RSA 2048 private key and a x509 certificate.
.PHONY: create-certificate
create-certificate:
	printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth" > auth/domain.ext
	openssl req \
	       -newkey rsa:2048 -nodes -sha256 -keyout auth/domain_private.key \
	       -x509 -days 365 -out auth/domain.crt \
				 -subj '/CN=localhost' -extensions EXT -config auth/domain.ext
	openssl rsa -in auth/domain_private.key -out auth/domain.key
	
## @help:start:Start Nginx infront of a service with authentication.
.PHONY: start
start: clean create-certificate
	docker run --rm --entrypoint htpasswd registry:2 -Bbn $(USR) $(PASSWORD) > auth/nginx.htpasswd
	sed -e 's#{{ SERVICE }}#$(SERVICE)#g' auth/nginx.conf.template > auth/nginx.conf
	docker run -it \
		-p $(NGINX_PORT):443 \
		-v $(CURDIR)/auth:/etc/nginx/conf.d \
		-v $(CURDIR)/auth/nginx.conf:/etc/nginx/nginx.conf:ro \
		nginx:alpine
	
## @help:stop:Stop Nginx.
.PHONY: stop
stop:
	
## @help:port-forward-serveo:Export NGINX_PORT port on internet using serveo service.
.PHONY: port-forward-serveo
port-forward-serveo:
	ssh -R 80:localhost:$(NGINX_PORT) serveo.net

## @help:port-forward-ngrok:Export NGINX_PORT port on internet using ngrok service.
.PHONY: port-forward-ngrok
port-forward-ngrok:
	ngrok tcp $(NGINX_PORT)
		
## @help:clean:Delete temporal files.
.PHONY: clean
clean:
	-rm auth/domain_private.key 
	-rm auth/domain.crt 
	-rm auth/domain.ext
	-rm auth/domain.key
	-rm auth/nginx.htpasswd
	-rm auth/nginx.conf
	