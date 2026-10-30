# ochag-webos — лаунчер, торрент-стек и RU-медиа на root-нутый LG webOS 4.x
TV   ?= 192.168.1.103
KEY  ?= $(HOME)/.ssh/lgtv_webos
ENV  := TV=$(TV) KEY=$(KEY)

.PHONY: all check test verify hearth torrserver omp youtube clean

all: check

# синтаксис + контрактные тесты (без телевизора)
check:
	@for f in install.sh lib/*.sh tools/*.sh hooks/*; do sh -n "$$f" || exit 1; done
	@command -v shellcheck >/dev/null && shellcheck -S warning install.sh lib/*.sh tools/*.sh hooks/* || echo "shellcheck не установлен — пропуск"
test:
	@sh tests/run.sh

# шаги на живом ТВ (идемпотентно)
hearth:     ; $(ENV) ./install.sh hearth
torrserver: ; $(ENV) ./install.sh torrserver
omp:        ; $(ENV) ./install.sh omp
youtube:    ; $(ENV) ./install.sh youtube
verify:     ; $(ENV) ./install.sh verify

clean:
	rm -rf cache
