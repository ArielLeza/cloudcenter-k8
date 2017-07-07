
DEPS = k8*/* profile.sh util/*

k8: $(DEPS)
	zip build/k8.zip -r $(DEPS)

.PHONY: clean

clean:
	-rm build/k8.zip
