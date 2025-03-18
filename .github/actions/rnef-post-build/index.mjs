import core from "@actions/core";
import github from "@actions/github";

async function run() {
  const token = core.getInput("github_token") || process.env.GITHUB_TOKEN;
  if (!token) {
    throw new Error("GitHub token is required");
  }

  const titleInput = core.getInput("title");
  if (!titleInput) {
    throw new Error("Title is required");
  }

  const artifactUrl = core.getInput("artifact_url");
  if (!artifactUrl) {
    throw new Error("Artifact URL is required");
  }

  const title = `## ${titleInput}`;
  const body = `🔗 [Download link](${artifactUrl}).\n\n
Note: if the download link expires, please re-run the workflow to generate a new build.\n\n
*Generated at ${new Date().toISOString()} UTC*\n`;

  const octokit = github.getOctokit(token);
  const { data: comments } = await octokit.rest.issues.listComments({
    ...github.context.repo,
    issue_number: github.context.issue.number,
  });

  const botComment = comments.find(
    (comment) =>
      comment.user.login === "github-actions[bot]" &&
      comment.body.includes(title)
  );

  if (botComment) {
    await octokit.rest.issues.updateComment({
      ...github.context.repo,
      comment_id: botComment.id,
      body: `${title}\n\n${body}`,
    });
    console.log("Updated comment");
  } else {
    await octokit.rest.issues.createComment({
      ...github.context.repo,
      issue_number: github.context.issue.number,
      body: `${title}\n\n${body}`,
    });
    console.log("Created comment");
  }
}

run();
