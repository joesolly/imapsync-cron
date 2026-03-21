IMAGE := joesolly/imapsync-cron

VERSION := $(shell \
  latest=$$(curl -s "https://hub.docker.com/v2/repositories/$(IMAGE)/tags?page_size=100" \
    | grep -oE '"name":"v[0-9]+"' | grep -oE 'v[0-9]+' | sort -V | tail -1); \
  num=$$(echo "$$latest" | tr -d 'v'); \
  if [ -n "$$num" ]; then echo "v$$(( $$num + 1 ))"; else echo "v1"; fi \
)

.PHONY: build tag push readme all

all: build tag push

build:
	docker build -t $(IMAGE):$(VERSION) .

tag:
	docker tag $(IMAGE):$(VERSION) $(IMAGE):latest

push:
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):latest

readme:
	@token=$$(curl -s -X POST "https://hub.docker.com/v2/users/login" \
	  -H "Content-Type: application/json" \
	  -d '{"username":"$(DOCKERHUB_USER)","password":"$(DOCKERHUB_PASS)"}' \
	  | grep -o '"token":"[^"]*"' | cut -d'"' -f4); \
	curl -s -X PATCH "https://hub.docker.com/v2/repositories/$(IMAGE)/" \
	  -H "Authorization: Bearer $$token" \
	  -H "Content-Type: application/json" \
	  -d "{\"full_description\": $$(cat README.md | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}" \
	  | grep -o '"full_description":"[^"]*"' | head -c 80 && echo " ...OK"
