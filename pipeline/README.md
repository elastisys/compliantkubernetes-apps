## Pipeline
The pipeline is now using a ubuntu based docker image now located at dockerhub on
[elastisys/ck8s-ops](https://hub.docker.com/r/elastisys/ck8s-ops). Each run of the
pipeline will generate its own image using the commit hash. Once a release is made
it will also tag a image with the same tag.

The pipeline will run on pull requests to main and on push to branches named
`Release-x`. The pipeline workflow is in `.github/workflows` and the scripts used are located in the `pipeline` directory.

## Ops image
The image built from the `Dockerfile` will have all the requirements to set up a new
cluster from scratch. This image might not have all the tools a developer might have
for debugging or working with the cluster.

In `Dockerfile.dev` these tools can be added to provide an image better suited for developers.
This image will also be built on every release under the name `elastisys/ck8s-ops:<version>-dev`

## Run ops image
To run the ops image locally with your home directory mounted:
```
./run-local-dockerfile.sh
```
This will be just like running your local shell but with the requirements of the
checked out version of ck8s. Use it to set up new clusters or to run operations
on an old version of ck8s.

#### Example scenario

You have a user running on version 0.1.0 of ck8s. In 0.1.0 helm 2.14 is used in
the cluster. In main helm has been upgraded to helm 3. You need to run maintenance
on the users cluster. Instead of downgrading your binary to helm 2.14 you do these steps.

```
cd user-config-repo/ck8s
./pipeline/run-local-dockerfile.sh
```
Then run what ever maintenance you need on that cluster.
