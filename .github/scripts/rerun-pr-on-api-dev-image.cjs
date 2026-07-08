async function rerunPrCiOnApiDevImage({ github, context, core }) {
  const { env } = require('node:process')
  const channel = env.INPUT_CHANNEL?.trim() || context.payload.client_payload?.channel || 'staging'
  const imageSha = context.payload.client_payload?.sha ?? 'unknown'
  const bases = channel === 'production' ? ['main', 'master'] : ['staging']
  const owner = context.repo.owner
  const repo = context.repo.repo
  const workflowFile = 'pr.yml'

  core.info(`API dev image published (channel=${channel}, sha=${imageSha})`)

  let rerunCount = 0
  let dispatchCount = 0

  for (const base of bases) {
    const { data: prs } = await github.rest.pulls.list({
      owner,
      repo,
      state: 'open',
      base,
      per_page: 100,
    })

    for (const pr of prs) {
      const { data: runs } = await github.rest.actions.listWorkflowRunsForRepo({
        owner,
        repo,
        workflow_id: workflowFile,
        head_sha: pr.head.sha,
        event: 'pull_request',
        per_page: 1,
      })

      if (runs.workflow_runs.length > 0) {
        const run = runs.workflow_runs[0]
        if (run.status === 'in_progress' || run.status === 'queued') {
          core.info(`Skipping PR #${pr.number}: CI already running`)
          continue
        }
        await github.rest.actions.reRunWorkflow({
          owner,
          repo,
          run_id: run.id,
        })
        rerunCount += 1
        core.info(`Re-ran CI for PR #${pr.number} (${pr.head.ref})`)
        continue
      }

      await github.rest.actions.createWorkflowDispatch({
        owner,
        repo,
        workflow_id: workflowFile,
        ref: pr.head.ref,
        inputs: {
          run_verify: true,
          run_integration: true,
          pr_base_ref: base,
        },
      })
      dispatchCount += 1
      core.info(`Dispatched CI for PR #${pr.number} on ${pr.head.ref}`)
    }
  }

  core.info(`Done. Re-ran ${rerunCount} workflow run(s); dispatched ${dispatchCount} new run(s).`)
}

module.exports = { rerunPrCiOnApiDevImage }
