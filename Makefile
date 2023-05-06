.PHONY: test lint verify clean

binary = fetch-attestation

test:
	go test -cover ./...

lint:
	golangci-lint run -E gofmt -E golint --exclude-use-default=false

verify:
	@go build -o $(binary) .
	@./attest-enclave.sh $(KANIKO_IMAGE_TAR) $(IMAGE_TAG) $(ENCLAVE)

clean:
	rm -f $(binary) Dockerfile
