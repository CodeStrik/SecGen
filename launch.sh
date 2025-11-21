#!/bin/bash
bundle _2.2.22_ exec ruby secgen.rb --scenario scenarios/tfg/remotely_exploitable_user_vulnerability.xml run --shutdown 2>&1 | tee log_completo.txt

