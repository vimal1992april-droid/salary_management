# How AI was used

The brief asks for AI to be used deliberately and for the process to be visible. All of the code, tests and documents
in this repository were written by an AI coding agent (Claude Code) working in one long session, **directed and
reviewed step by step by the repository's owner**. This is an account of how that worked, including what the AI got
wrong and what caught it, because that is the useful part.

## How the work was directed

The owner set the direction; the AI did not choose the scope or the order.

- **Documents before code.** The owner pasted the assessment brief and asked the AI to read it carefully and first
  write the implementation plan (with TDD as a central rule) and a README, before building anything. Those became
  [requirements.md](requirements.md), [implementation-plan.md](implementation-plan.md) and the README.
- **The stack.** The AI's first default was Laravel. The owner corrected it: "we need to build the app in Rails and the
  frontend in React". Nothing had been generated yet, so nothing was wasted.
- **How commits should look.** The owner wanted the history to show what is being built, step by step. The AI first
  misread this as permission to start building and made four commits without being asked; the owner said so, and
  they were removed from `main` (kept on a local backup branch, never pushed) and redone once building was approved.
- **Go-ahead per stage.** Work started only on an explicit "start building the backend" / "proceed to next", and
  nothing was pushed to GitHub except when the owner said "push".

The instructions that shaped the work, in the owner's words (translated where they were in Hinglish):

> "read it carefully and prepare documentation on how we are going to build this, and keep in mind TDD is very
> important; first build a doc of implementation and a readme file about the project"
>
> "we need to build the app in Rails and the frontend in React"
>
> "for whatever development happens, the commits should let us see what we are building step by step"
>
> "okay, let's start building the backend, but keep in mind we have to make commits as we proceed"

## The method

Every feature followed the same loop, and the commit history shows it (23 red commits, each followed by its green one):

1. The AI writes a small set of tests that state the behaviour in plain words, runs them, and confirms they **fail for
   the right reason** (a missing constant is fine; an assertion that cannot fail is not). Commit: `test: ... (red)`.
2. It writes the least code that makes them pass and runs the whole suite plus the linters. Commit: `feat: ... (green)`.
3. Where going green shows that a test or a design was wrong, the fix goes in the green commit with an explanation
   of what was wrong, rather than being quietly rewritten.

Test data is small and hand-computed, so the expected value can be checked by reading it: the median of
`10k, 20k, 30k, 100k` is 25k, and ten peers on 100k to 109k plus a 140k salary give outlier fences of 95,000 and
115,000.

## What the AI got wrong, and what caught it

Nothing here was found by rereading the AI's own confidence; each was found by a test, a tool or a real run, and is
recorded in the commit that fixed it.

| Mistake | Caught by |
|---|---|
| Removed the `json` version pin after checking only that JSON *renders*; JSON *parsing* is broken on json 3.x, so every POST returned 400 | The first test that POSTed a JSON body |
| Left the `csv` gem out; it stopped being a default gem in Ruby 3.4 | A `LoadError` in the first export test |
| Test factories used `build`, which does not save associated records, so a currency code pointed at nothing (twice) | Foreign-key and validation failures |
| `currency ||= country.currency` silently replaced an unknown currency code instead of rejecting it | A test written for exactly that case |
| The plan said `PATCH` would ignore a salary sent to it. For money data that is dangerous: a client would believe the salary changed | Noticed while going green; it is now a 422, with the reasoning in the commit |
| A comment (and the first test numbers) gave wrong outlier fences | Recomputing by hand while writing the assertions |
| A Brakeman "SQL injection" warning on a whitelisted table name | Brakeman; fixed by restructuring with Arel rather than suppressing it |
| Wrote three query timings into a doc that had never been measured ("about 15 ms") | Review of the output; re-measured and corrected in its own commit |
| A shell heredoc turned an em dash into a Windows-1252 byte, which is invalid UTF-8 | The IDE showing the file; every source file was then validated as UTF-8 |
| A "test" commit swept in unrelated, already-staged deletions | Reading `git status` before committing; regrouped into four clean commits (never pushed) |
| First Docker build put the gems under `/app/vendor/bundle` because `BUNDLE_PATH` was unset | The build failing |
| The production image answered `/employees` with 404 to clients sending only `Accept: */*`, and cached the app shell for a year at `/` | Building and running the image, then a regression test for each |
| Validation messages stayed under fields the user had already corrected | A real browser (Playwright); the jsdom tests only ever checked that messages *appeared* |

## Where verification came from

Tests and tools decide whether something is right, not the AI:

- 264 backend tests, 155 frontend tests, RuboCop, Brakeman and the linter, replayed in clean containers on the Ruby
  and Node versions CI uses (which also proved the schema builds an empty database);
- the frontend's hand-written test fixtures compared with the real API's responses, so mocked tests cannot
  quietly drift from the backend (all 17 request shapes match);
- query-count assertions for N+1, a repeatable HTTP benchmark for speed ([performance.md](performance.md));
- the production Docker image run against a real Postgres and driven by a real browser.

## Limits

- The AI wrote all of the code, so the owner should read the diffs (each commit says why) before relying on it. The
  plan and §17 of it list every decision and every place the build changed the plan.
- **Not done, and not claimed:** a run of the GitHub Actions workflow on GitHub, a deploy to a real host, and the demo
  video. Those need the owner's accounts and screen.

## Patterns that worked

- Ask for the failing test first and make the AI show it failing; a test that cannot fail proves nothing.
- Prefer small, exact datasets over large realistic ones in tests.
- After a change of environment or runtime (Ruby 3.4, Node 22, Docker), replay the checks there instead of trusting
  the machine the code was written on.
- Compare mocks with the real thing at least once.
- Treat a warning from a tool as a question about the code, not a nuisance to silence.
