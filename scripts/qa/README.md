# QA installer script for Welkin Apps

This is an implementation of an installer script for Weklin Apps that:

- is as independent as possible from the "installer" layer (Kubespray or CAPI)
- has been tested and should work well on multiple cloud providers (ElastX, Upcloud, Brewer)
- aims to automate the deployment of Apps, in a as vanilla as possible form
- for a release version, the deployed Apps should pass all end-to-end test suites
- allows skipping to a certain step in the process, manually confirming each step, or dry-running to list the steps

## Configuration

The script is configured via a simple `.json` file. The configuration data types are handled by the `config.py` module,
which also doubles as a runnable script.

When run without arguments, it will produce a "maximal" configuration file, a file where all properties are set, which
should serve as a good guideline of what's possible (but necessarily _required_) to configure:

  <details><summary>Maximal configuration example</summary>

```json
{
  "kubeloginClientSecret": "set-me",
  "adminGroup": "set-me",
  "dex": {
    "gcp": {
      "clientID": "set-me",
      "clientSecret": "set-me"
    }
  },
  "dnsProvider": {
    "domain": "set-me",
    "aws": {
      "hostedZone": "set-me",
      "secrets": {
        "accessKey": "set-me",
        "secretKey": "set-me"
      }
    }
  },
  "externalLoadbalancers": {
    "scAddress": "set-me",
    "scDomainName": "set-me",
    "scProxyProtocol": false,
    "wcAddress": "set-me",
    "wcDomainName": "set-me",
    "wcProxyProtocol": false
  },
  "objectStorage": {
    "config": {
      "s3": {
        "region": "set-me",
        "regionEndpoint": "set-me"
      }
    },
    "secrets": {
      "s3": {
        "accessKey": "set-me",
        "secretKey": "set-me"
      },
      "swift": {
        "applicationCredentialID": "set-me",
        "applicationCredentialSecret": "set-me"
      }
    }
  },
  "wcSubnets": {
    "apiServer": [
      "set-me"
    ],
    "nodes": [
      "set-me"
    ],
    "ingress": [
      "set-me"
    ]
  },
  "scSubnets": {
    "apiServer": [
      "set-me"
    ],
    "nodes": [
      "set-me"
    ],
    "ingress": [
      "set-me"
    ]
  },
  "networkPlugin": "set-me"
}
```

  </details>

When run with the `--minimal` argument, it will produce a "minimally" viable config, that is, a config file which
won't trigger any errors if no other fields are configured, but that also might not be _sufficient_ for a correct
setup (depending on cloud provider, installer, etc.)

  <details><summary>Minimal configuration example</summary>

```json
{
  "kubeloginClientSecret": "set-me",
  "adminGroup": "set-me",
  "dex": {
    "gcp": {
      "clientID": "set-me",
      "clientSecret": "set-me"
    }
  },
  "dnsProvider": {
    "domain": "set-me",
    "aws": {
      "hostedZone": "set-me",
      "secrets": {
        "accessKey": "set-me",
        "secretKey": "set-me"
      }
    }
  },
  "objectStorage": {
    "secrets": {
      "s3": {
        "accessKey": "set-me",
        "secretKey": "set-me"
      }
    }
  }
}
```

  </details>

This script has been tested on ElastX, Upcloud and Brewer, but it could potentially be viable on other cloud providers.

To check, start from the minimal config and keep adding configuration keys as needed until you get a good setup.

### Credential scope

- The AWS credentials are used by the external DNS controller to automatically set up subdomains for both the SC and the WC.
- The GCP credentials are used to set up the Dex connector in the service cluster. Refer to the [IDP preparation page](https://elastisys.io/welkin/user-guide/prepare-idp/#google) in the Welkin documentation for details.
- Object storage credentials are used for 🥁 accessing object storage and should be set according to cloud provider.
- The `kubeloginClientSecret` should match the value under `.clusters.wc.oidc.client_secret` when installing with CAPI. This allows us to avoid an additional Control Plane rollout during the Apps install, thus avoiding any interaction with the installer layer.
- For Kubespray, check the generated kubectl config file for the Workload Cluster (usually `$CK8S_CONFIG_PATH/.state/kube_config_wc.yaml`) and look for the value of the `--oidc-client-secret` argument.

> [!NOTE]
>
> The script assumes that the `$CK8S_CONFIG_PATH/dex-google-group-claim/secret/google-sa-secret.yml` exists and is populated with the proper key (corresponding to the IDP credentials used in the secrets config file)

### Sample configuration files

  <details><summary>Elastx</summary>

The only tricky bit on Elastx is that we have to use `/24` subnets for API servers and nodes,
to prevent the `update-ips` script from filling in specific node IPs because the IP associated with the
load balancer won't be included.

```json
{
  "kubeloginClientSecret": "redacted",
  "adminGroup": "admins@example.com",
  "dex": {
    "gcp": {
      "clientID": "hocus-bogus.apps.googleusercontent.com",
      "clientSecret": "GOCSPX-redacted"
    }
  },
  "dnsProvider": {
    "domain": "dev-ck8s.com",
    "aws": {
      "hostedZone": "redacted",
      "secrets": {
        "accessKey": "redacted",
        "secretKey": "redacted"
      }
    }
  },
  "objectStorage": {
    "secrets": {
      "s3": {
        "accessKey": "redacted",
        "secretKey": "redacted"
      },
      "swift": {
        "applicationCredentialID": "redacted",
        "applicationCredentialSecret": "redacted"
      }
    }
  },
  "scSubnets": {
    "apiServer": ["172.16.35.0/24"],
    "nodes": ["172.16.35.0/24"]
  },
  "wcSubnets": {
    "apiServer": ["172.16.36.0/24"],
    "nodes": ["172.16.36.0/24"]
  },
  "networkPlugin": "calico"
}
```

  </details>
  <details><summary>Upcloud</summary>

Find the public hostnames for your SC/WC on the [Load Balancers page](https://hub.upcloud.com/load-balancer/services) of the Upcload web interface.

```json
{
  "kubeloginClientSecret": "redacted",
  "adminGroup": "admins@example.com",
  "dex": {
    "gcp": {
      "clientID": "hocus-bogus.apps.googleusercontent.com",
      "clientSecret": "GOCSPX-redacted"
    }
  },
  "dnsProvider": {
    "domain": "dev-ck8s.com",
    "aws": {
      "hostedZone": "redacted",
      "secrets": {
        "accessKey": "redacted",
        "secretKey": "redacted"
      }
    }
  },
   "externalLoadbalancers": {
    "scDomainName": "lb-redacted.upcloudlb.com",
    "scProxyProtocol": true,
    "wcDomainName": "lb-redacted.upcloudlb.com",
    "wcProxyProtocol": true
  },
  "objectStorage": {
    "config": {
      "s3": {
        "region": "fi-hel2",
        "regionEndpoint": "https://redacted.upcloudobjects.com"
      }
    },
    "secrets": {
      "s3": {
        "accessKey": "redacted",
        "secretKey": "redacted"
      }
    }
  },
  "networkPlugin": "calico"
}
```

  </details>
  <details><summary>Brewer</summary>

We're going with very permissive subnets for Brewer, but you can totally close these down to specific IPs if you want.

```json
{
  "kubeloginClientSecret": "redacted",
  "adminGroup": "admins@example.com",
  "dex": {
    "gcp": {
      "clientID": "hocus-bogus.apps.googleusercontent.com",
      "clientSecret": "GOCSPX-redacted"
    }
  },
  "dnsProvider": {
    "domain": "dev-ck8s.com",
    "aws": {
      "hostedZone": "redacted",
      "secrets": {
        "accessKey": "redacted",
        "secretKey": "redacted"
      }
    }
  },
  "objectStorage": {
    "config": {
      "s3": {
        "region": "us-east-1",
        "regionEndpoint": "https://s3.internal.elastisys.se:8443"
      }
    },
    "secrets": {
      "s3": {
        "accessKey": "redacted",
        "secretKey": "redacted"
      }
    }
  },
  "scSubnets": {
    "nodes": [ "0.0.0.0/0" ],
    "apiServer": [ "0.0.0.0/0" ]
  },
  "wcSubnets": {
    "nodes": [ "0.0.0.0/0" ],
    "apiServer": [ "0.0.0.0/0" ]
  },
  "networkPlugin": "calico"
}
```

  </details>

## Honorable mentions

> [!NOTE]
>
> The script doesn't handle the creation of object storage buckets.
>
> On a fresh environment, the following incantation usually does the job:
>
> `sops exec-file --no-fifo "${CK8S_CONFIG_PATH}/.state/s3cfg.ini" "scripts/S3/entry.sh --s3cfg {} create"`
