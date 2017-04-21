BUILDCTL
========


# Install
To install the software do
```
make prepare
make install
```

# Update
To update run
```
make update
```

# Remove
This will remove the tool
```
make clean
```

## Usage
To build an app from source run
```
buildctl -r build -b /etc/buildctl/apps/dovecot.conf
```
To list all available versions of apps
```
buildctl -r list-versions
```
Get active version of app
```
buildctl -r get-active -a dovecot
```

And more help can be found with
```
buildctl -h
```
