# actions-runner-full

Full-featured GitHub Actions **self-hosted runner** image for
**ARC (Actions Runner Controller)** on Kubernetes.

Extends the official ARC base (`ghcr.io/actions/actions-runner`) with:

| Tool | Purpose |
|------|---------|
| `git` | already on base; explicit |
| `python3` + `pip` + `pyyaml` | template YAML validation, scripts |
| `ruby` | YAML/tooling |
| `build-essential` | make / gcc for building node daemons |
| `autoconf automake libtool pkg-config` | `./autogen.sh && ./configure` (crypto node builds) |
| `curl`, `jq`, `ca-certificates` | general CI |

## Usage in ARC

Point an ARC runner scale set at this image (in `containerMode: dind` so the
DinD sidecar provides the docker daemon, and this image supplies the tooling):

```yaml
containerMode:
  type: dind
# runner image override -> ghcr.io/snoby-demo-org/actions-runner-full:full
```

Built automatically on push to `main` (GitHub-hosted `ubuntu-latest`),
pushed to `ghcr.io/snoby-demo-org/actions-runner-full:full` and `:latest`.

## Why not `myoung34` / `summerwind`?

We deploy ARC v2 with `containerMode: dind` — that already provides the docker
daemon via a sidecar. Community images like `myoung34/docker-github-actions-runner`
bundle their own docker daemon (redundant/conflicting with ARC's dind sidecar).
This image instead layers the tools we need onto the official ARC base, staying
compatible with ARC's dind model and fully under our control.
