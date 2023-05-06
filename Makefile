.PHONY: test lint verify clean

binary = fetch-attestation

test:
	go test -cover ./...

lint:
	golangci-lint run -E gofmt -E golint --exclude-use-default=false

verify:
	docker load -i "$(KANIKO_IMAGE_TAR)"
	@go build -o $(binary) .
	@./attest-enclave.sh $(IMAGE_TAG) $(ENCLAVE)

clean:
	rm -f $(binary) Dockerfile
