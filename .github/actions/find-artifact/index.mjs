import * as core from "@actions/core";
import * as github from "@actions/github";

const perPage = 100; // Maximum allowed by GitHub API

async function fetchArtifacts(octokit, repository, name) {
  const result = [];
  let page = 1;

  while (true) {
    const response = await octokit.rest.actions.listArtifactsForRepo({
      owner: repository.split("/")[0],
      repo: repository.split("/")[1],
      name,
      per_page: perPage,
      page,
    });

    const artifacts = response.data.artifacts;
    result.push(...artifacts);

    if (artifacts.length < perPage) {
      break;
    }

    page++;
  }

  result.sort((a, b) => new Date(b.expires_at) - new Date(a.expires_at));
  return result;
}

async function run() {
  try {
    const token = core.getInput("github_token") || process.env.GITHUB_TOKEN;

    if (!token) {
      throw new Error("GitHub token is required");
    }

    const repository = core.getInput("repository");
    if (!repository) {
      throw new Error("Repository is required");
    }

    const name = core.getInput("name");
    if (!name) {
      throw new Error("Artifact name is required");
    }

    const reSign = core.getInput("re_sign");
    const prNumber = core.getInput("pr_number");

    const octokit = github.getOctokit(token);
    const artifactsByName = await fetchArtifacts(octokit, repository, name);
    const artifactsByPrNumber =
      prNumber && reSign
        ? await fetchArtifacts(octokit, repository, `${name}-${prNumber}`)
        : [];
    const artifacts = [...artifactsByPrNumber, ...artifactsByName];

    if (artifacts.length === 0) {
      return;
    }

    console.log(`Found ${artifacts.length} related artifacts:`);
    for (const artifact of artifacts) {
      console.log(
        `- ID: ${artifact.id}, Name: ${artifact.name}, Size: ${formatSize(
          artifact.size_in_bytes
        )}, Expires at: ${artifact.expires_at}`
      );
    }

    const firstArtifact = artifacts.find((artifact) => !artifact.expired);
    console.log(`First artifact: ${JSON.stringify(firstArtifact, null, 2)}`);

    const url = formatDownloadUrl(
      repository,
      firstArtifact.workflow_run.id,
      firstArtifact.id
    );
    console.log("Stable download URL:", url);

    let artifactName = name;
    // There are artifacts from PR but the base artifact is gone, recreate with the original name
    if (artifactsByName.length === 0) {
      artifactName = name;
      // First time an artifact is re-signed, it's not yet in artifact storage, setting the name explicitly.
    } else if (prNumber && reSign) {
      artifactName = `${name}-${prNumber}`;
    }
    core.setOutput("artifact-name", artifactName);
    core.setOutput("artifact-id", firstArtifact.id);
    core.setOutput("artifact-url", url);
    core.setOutput(
      "artifact-ids",
      artifactsByPrNumber.map((artifact) => artifact.id).join(" ")
    );
  } catch (error) {
    core.setFailed(`Action failed with error: ${error.message}`);
  }
}

// The artifact URL returned by the GitHub API expires in 1 minute, we need to generate a permanent one.
function formatDownloadUrl(repository, workflowRunId, artifactId) {
  return `https://github.com/${repository}/actions/runs/${workflowRunId}/artifacts/${artifactId}`;
}

function formatSize(size) {
  if (size > 0.75 * 1024 * 1024) {
    return `${(size / 1024 / 1024).toFixed(2)} MB`;
  }

  return `${(size / 1024).toFixed(2)} KB`;
}

run();
