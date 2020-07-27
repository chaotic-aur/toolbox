#!/usr/bin/env bash

function machine-setup() {
    set -euo pipefail

    local _MACHINE_NAME="$1"
    local _DATA="${CAUR_PACKAGES}/machines/${_MACHINE_NAME}"
    if [[ -z "${_MACHINE_NAME}" ]] \
        || [[ ! -d "${_DATA}" ]]; \
        then

        echo 'Invalid machine name or machine not found.'

        return 4
    fi

    local _CONF="${_DATA}/conf"
    source "${_CONF}"
    cp -v "${_CONF}" /etc/chaotic.conf

    local _SCHEDS="${_DATA}/schedules"
    if [[ -d "${_SCHEDS}" ]]; then
        pushd "${_SCHEDS}"

        for _SCHED in !(*.timer); do
            [[ "${_SCHED}" == '!(*.timer)' ]] && continue

            local _QUEUE="$(readlink -f "${_SCHED}" | xargs basename)"
            if [[ -z "${_QUEUE}" ]]; then
                echo 'Failure in following schedule syslink'
                return 5
            fi

            cat << EOF | stee "/etc/systemd/system/${CAUR_SERVICES_PREFIX}${_SCHED}.service"
[Unit]
Description=Chaotic's scheduled ${_SCHED} build

[Service]
User=root
Group=root
ExecStart=${CAUR_PREFIX}/bin/chaotic queue-run-nspawn ${_QUEUE}

[Install]
WantedBy=multi-user.target
EOF

            if [[ -f "${_SCHED}.timer" ]]; then
                cat << EOF | stee "/etc/systemd/system/${CAUR_SERVICES_PREFIX}${_SCHED}.timer"
[Unit]
Description=Chaotic's scheduled ${_SCHED} build

[Timer]
$(cat "${_SCHED}.timer")

[Install]
WantedBy=timers.target
EOF

            systemctl daemon-reload
            systemctl enable "${CAUR_SERVICES_PREFIX}${_SCHED}.timer"
        fi
        
        done

        popd
    fi

    return 0
}