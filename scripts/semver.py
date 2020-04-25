#!/usr/bin/env python

import json
import sys
import argparse

class Semver():

    def __init__(self, filename = "version.json"):
        self.default_version_data = \
"""
{
    "version": { "major": 0, "minor": 0, "patch": 0 }
}
"""
        # supported types
        self.types = ['major', 'minor', 'patch']
        self.filename = filename

        self.version = None
        try:
            with open(self.filename, "r") as fh:
                self.version = json.load(fh)
        except FileNotFoundError:
            self.version = json.loads(self.default_version_data)
        except IOError:
            print("IO error, don't know how to deal with this!")
            exit(1)

    # expected branch prefixes: major/*, feature/*, patch/*, hotfix/*.
    # Everything else will be deemed a patch

    def get_next_version(self, release_type="patch"):
        if release_type not in self.types:
            print("Invalid release type: {}!".format(release_type))
            exit(1)

        if release_type.lower() == "patch":
            self.version['version']['patch'] = self.version['version']['patch'] + 1
        elif release_type.lower() == "minor":
            self.version['version']['minor'] = self.version['version']['minor'] + 1
            # Patch version MUST be reset to 0 when minor version is incremented.
            self.version['version']['patch'] = 0
        elif release_type.lower() == "major":
            self.version['version']['major'] = self.version['version']['major'] + 1
            # Minor and patch version MUST be reset to 0 when major version is incremented.
            self.version['version']['minor'] = 0
            self.version['version']['patch'] = 0
        return self.version

    def commit(self):
        # write the version file
        try:
            with open(self.filename, "w") as fh:
                json.dump(self.version, fh)
        except IOError:
            print("IO error, don't know how to deal with this!")
            exit(1)

    def get_next_version_from_branch(self, branch="patch/dummy"):
        release_type = "minor"
        if branch.startswith("feature/"):
            release_type = "minor"
        elif branch.startswith("hotfix/"):
            release_type = "patch"
        elif branch.startswith("patch/"):
            release_type = "patch"
        elif branch.startswith("major/"):
            release_type = "major"
        else:
            release_type = "patch"

        return self.get_next_version(release_type)

    def as_string(self):
        return "{0}.{1}.{2}".format(
            self.version['version']['major'],
            self.version['version']['minor'],
            self.version['version']['patch']
        )

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument('-b', '--branch_name', metavar='<branch_name>', 
        type=str, required=True, 
        help="The branch name.")
    ap.add_argument('-p', '--patch', action='store_true', default=False, 
        help="Increment the patch number.") 
    ap.add_argument('-m', '--minor', action='store_true', default=False, 
        help="Increment the minor number.") 
    ap.add_argument('-M', '--Major', action='store_true', default=False, 
        help="Increment the Major number.") 
    args = ap.parse_args()
    #print(f"Using branch: {args.branch_name}")
    #print(f"Number of commits: {args.commit_count}")
    # The type of args.commit is boolean
    #print(f"commit: {args.commit}")

    sv = Semver("version.json")
    if args.patch:
    	v = sv.get_next_version("patch")
    elif args.minor:
    	v = sv.get_next_version("minor")
    elif args.Major:
    	v = sv.get_next_version("major")
    else:
    	v = sv.get_next_version_from_branch(branch=args.branch_name)
    sv.commit()
    print("{0}".format(sv.as_string()))
