#!/bin/bash
ssh root@104.156.250.136 "journalctl -u panel-attack -f --no-pager"
