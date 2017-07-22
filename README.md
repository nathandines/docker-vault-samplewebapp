# docker-vault-samplewebapp

## Description

This repo contains a (potential) example pattern which could be used when
utilising Vault as a secret backend for a webapp which needs to access a
PostgreSQL DB backend.

This example relies on an automated process (`start_app.sh` emulates this)
deploying a webapp, and passing it wrapped approle credentials, which it then
uses to generate a Vault token which `consul-template` maintains the renewal
for, while a Python webapp hosts a simple people list database; the page also
exposes some of the database authentication information.

## Requirements

-   Docker (uses `docker-compose`)
-   Vault (binary must be accessible from your `PATH`)

## How to use

Everything is scripted, so you should be able to get by, by simply doing the following:

Setup the Vault and PostgreSQL backend:

```
./init_backend.sh
```

Run the webapp (you can navigate to this on `http://localhost:80`):

```
./start_app.sh
```

Clean up your environment when complete:

```
./clean_environment.sh
```
