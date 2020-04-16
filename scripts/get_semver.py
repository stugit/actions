#!/usr/bin/env python

import json

try:
	with open("version.json", "r") as fh:
		version = json.load(fh)
except FileNotFoundError:
	print("Error: version.json file not found!")
	exit(1)
except IOError:
	print("IO error, error encountered reading the file!")
	exit(1)


def as_string(version_):
	return "{0}.{1}.{2}".format(
		version_['version']['major'],
		version_['version']['minor'],
		version_['version']['patch']
	)

print("{0}".format(as_string(version_=version)))
