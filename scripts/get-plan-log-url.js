// Builds a deep link to the log of the step that printed the Tofu plan, so
// it can be referenced from the PR summary comment.
//
// The "Print Tofu Plan" step re-prints the plan output captured by
// "Run Tofu Plan", avoiding interleaved output when steps run in parallel
// (see the comment on "Print Tofu Plan" in tofu-plan.yml). We link to
// whichever of those two steps actually exists, preferring the reprint.
const PLAN_STEP_NAMES = ['Print Tofu Plan', 'Run Tofu Plan'];

module.exports = async ({ github, context, core }) => {
  const jobDisplayName = process.env.JOB_DISPLAY_NAME;

  const jobs = await github.paginate(github.rest.actions.listJobsForWorkflowRun, {
    owner: context.repo.owner,
    repo: context.repo.repo,
    run_id: context.runId,
  });

  const job = jobs.find((j) => j.name === jobDisplayName);
  if (!job) {
    core.warning(`No job named "${jobDisplayName}" found for this workflow run; skipping plan log URL.`);
    return;
  }

  const step = PLAN_STEP_NAMES
    .map((name) => job.steps.find((s) => s.name === name))
    .find(Boolean);
  if (!step) {
    core.warning(`No step named ${PLAN_STEP_NAMES.map((n) => `"${n}"`).join(' or ')} found in job "${jobDisplayName}"; linking to the job instead of the specific step.`);
  }

  const prNumber = context.payload.pull_request?.number;

  // The job link alone is already useful, so build it up with whatever
  // optional pieces (step anchor, pr query param) are available.
  const jobUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}/job/${job.id}`;
  const prQuery = prNumber ? `?pr=${prNumber}` : '';
  const stepAnchor = step ? `#step:${step.number}:1` : '';
  const logUrl = `${jobUrl}${prQuery}${stepAnchor}`;
  core.info(`LOG_URL=${logUrl}`);
  core.setOutput('log_url', logUrl);
};
