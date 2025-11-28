#!/bin/bash

set -eu

# This uses ruby from rbenv, located at ~/src/rbenv

bundle exec jekyll serve --host 0.0.0.0 --baseurl=""
