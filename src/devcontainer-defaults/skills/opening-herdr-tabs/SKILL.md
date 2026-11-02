---
name: opening-herdr-tabs
description: Opens a file from this dev container in a new Herdr terminal tab, rendered by the container's own vim or less. Use after producing a report, code review, plan, spec, or long diff that the user should read rather than scroll past in the transcript, and whenever the user asks to open, show, or pop something up in a tab or pane. Requires the herdr-open.sh helper and HERDR_ENV=1, both absent outside a Herdr-managed dev container.
---

# Opening Herdr tabs

Herdr runs on the host, so a file written in this container is not something the
user can open by hand. `herdr-open.sh` crosses that boundary. The file is never
copied to the host and does not need to be in the bind-mounted workspace — a
scratchpad path works.

## Usage

Run exactly this. It takes no flags and no command; do not add any.

```bash
herdr-open.sh <viewer> <tab name> <file>
```

| Argument | Accepts |
| --- | --- |
| `viewer` | `vi`, `vim`, `view`, `nvim`, `less`, `bat` — must be installed in this container |
| `tab name` | letters, digits, space, `.`, `_`, `-`; 40 characters or fewer |
| `file` | a readable regular file inside this container |

Write the file first, then open it:

```bash
herdr-open.sh vi "Code Review" /tmp/review-findings.md
```

The tab opens without stealing focus, so it waits for the user instead of
interrupting them. Name the tab in your reply so they know it is there.

## When to use it

Use it for output meant to be *read*: review findings, an authored spec or plan,
a generated report, a long diff.

Do not use it for source files the user is already editing, and do not open a
tab for every file you touch. One tab per report. Re-running it opens a second
tab, so close the first if you are replacing a report — and only if you opened
it.

## Failure handling

The helper validates its own arguments and prints a specific reason on stderr
with exit 2. Read the message and fix the call; a rejected viewer or tab name
means the argument was malformed, not that the tab system is broken.

Exit 0 with no output means this is not a Herdr dev container. Say so and put
the content in your reply instead.

For anything this cannot express, do the work in your own shell and open the
resulting file. Do not drive the Herdr socket directly.
