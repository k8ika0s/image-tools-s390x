# Copyright Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

REGISTRIES ?= quay.io/cilium
PRIMARY_REGISTRY ?= $(word 1,$(REGISTRIES))

PUSH ?= false
EXPORT ?= false
PLATFORMS ?= linux/amd64,linux/arm64
ifeq ($(INCLUDE_S390X),true)
PLATFORMS := $(PLATFORMS),linux/s390x
endif
S390X_ONLY := $(if $(filter linux/s390x,$(PLATFORMS)),true,false)
S390X_TESTER_IMAGE ?= $(PRIMARY_REGISTRY)/image-tester:$(shell scripts/make-image-tag.sh images/tester)
S390X_COMPILERS_IMAGE ?= $(PRIMARY_REGISTRY)/image-compilers:$(shell scripts/make-image-tag.sh images/compilers)

all-images: lint maker-image tester-image compilers-image bpftool-image llvm-image network-perf-image startup-script-image checkpatch-image iptables-image


lint:
	scripts/lint.sh

.buildx_builder:
	@if docker buildx --help 2>/dev/null | grep -qE '(^|[[:space:]])create([[:space:]]|$$)'; then \
		docker buildx create --platform $(PLATFORMS) --buildkitd-flags '--debug' > $@ 2>/dev/null || \
		docker buildx create --platform $(PLATFORMS) > $@ 2>/dev/null || \
		docker buildx create > $@; \
	else \
		echo "buildx create is unavailable; using default builder context" >&2; \
		: > $@; \
	fi

maker-image: .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) scripts/build-image.sh image-maker images/maker $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)

tester-image: .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) TEST=true scripts/build-image.sh image-tester images/tester $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)

ifeq ($(S390X_ONLY),true)
compilers-image: tester-image .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) TEST=true TESTER_IMAGE=$(S390X_TESTER_IMAGE) scripts/build-image.sh image-compilers images/compilers $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)
else
compilers-image: .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) TEST=true scripts/build-image.sh image-compilers images/compilers $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)
endif

ifeq ($(S390X_ONLY),true)
bpftool-image: compilers-image tester-image .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) TEST=true TESTER_IMAGE=$(S390X_TESTER_IMAGE) COMPILERS_IMAGE=$(S390X_COMPILERS_IMAGE) scripts/build-image.sh cilium-bpftool images/bpftool $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)
else
bpftool-image: .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) TEST=true scripts/build-image.sh cilium-bpftool images/bpftool $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)
endif

ifeq ($(S390X_ONLY),true)
llvm-image: compilers-image tester-image .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) TEST=true TESTER_IMAGE=$(S390X_TESTER_IMAGE) COMPILERS_IMAGE=$(S390X_COMPILERS_IMAGE) scripts/build-image.sh cilium-llvm images/llvm $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)
else
llvm-image: .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) TEST=true scripts/build-image.sh cilium-llvm images/llvm $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)
endif

startup-script-image: .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) scripts/build-image.sh startup-script images/startup-script $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)

checkpatch-image: .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) scripts/build-image.sh cilium-checkpatch images/checkpatch $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)

network-perf-image: .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) scripts/build-image.sh network-perf images/network-perf $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)

iptables-image: .buildx_builder
	PUSH=$(PUSH) EXPORT=$(EXPORT) scripts/build-image.sh iptables images/iptables $(PLATFORMS) "$$(cat .buildx_builder)" $(REGISTRIES)
