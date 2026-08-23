+++
version = 2
id = "verification.growth.cross-project-scope"
kind = "verification"
method = "automatic"
target = "test/run.sh"
+++

# Verify cross-project adaptation scope

Run `./test/run.sh`. The scenario keeps project-a and project-b on separate observed experiences, observes the same general adaptation in both environments, and verifies that a project-a-only adaptation is not recommended for project-b, is not recommended without a project, and rejects an out-of-scope observation.
