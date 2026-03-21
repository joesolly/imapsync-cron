IMAGE := joesolly/imapsync-cron

VERSION := $(shell \
  latest=$$(curl -s "https://hub.docker.com/v2/repositories/$(IMAGE)/tags?page_size=100" \
    | grep -oE '"name":"v[0-9]+"' | grep -oE 'v[0-9]+' | sort -V | tail -1); \
  num=$$(echo "$$latest" | tr -d 'v'); \
  if [ -n "$$num" ]; then echo "v$$(( $$num + 1 ))"; else echo "v1"; fi \
)

.PHONY: build tag push readme git all

all: build tag push readme git

build:
	docker build -t $(IMAGE):$(VERSION) .

tag:
	docker tag $(IMAGE):$(VERSION) $(IMAGE):latest

push:
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):latest

git:
	git add -A
	git diff --cached --quiet || git commit -m "Release $(VERSION)"
	git tag $(VERSION)
	git push --follow-tags

readme:
	@creds=$$(echo "https://index.docker.io/v1/" | docker-credential-osxkeychain get); \
	user=$$(echo "$$creds" | python3 -c 'import json,sys; c=json.load(sys.stdin); print(c["Username"])'); \
	pass=$$(echo "$$creds" | python3 -c 'import json,sys; c=json.load(sys.stdin); print(c["Secret"])'); \
	token=$$(curl -s -X POST "https://hub.docker.com/v2/users/login" \
	  -H "Content-Type: application/json" \
	  -d "{\"username\":\"$$user\",\"password\":\"$$pass\"}" \
	  | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])'); \
	curl -s -X PATCH "https://hub.docker.com/v2/repositories/$(IMAGE)/" \
	  -H "Authorization: Bearer $$token" \
	  -H "Content-Type: application/json" \
	  -d "{\"full_description\": $$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' < README.md)}" \
	  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("OK" if "full_description" in d else d)'
