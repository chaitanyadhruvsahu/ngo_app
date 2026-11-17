# NGO prototype demo — 29 October 2026

Local URL: http://127.0.0.1:15173/#/login

This demonstration uses a separate SQLite database and fictional records, not the existing project database. The frontend and API share port 15173. A separate local worker checks scheduled notifications every 15 seconds. Keep the computer awake during the presentation. This localhost URL works only on this computer, not on attendees' phones.

## Accounts

All three accounts use the demo-only password `Demo-only-password-2026`.

| Login | Purpose |
| --- | --- |
| admin@demo.test | NGO staff: fellows, jobs, review, notifications, reports |
| asha@demo.test | Completed fellow profile, sample document, two volunteers, three jobs |
| ravi@demo.test | Email-verified fellow with incomplete profile for onboarding demonstration |

Use a regular browser window for admin and a private/incognito window for Asha. Two regular tabs share login storage and should not be used for different roles.

## Suggested 12–15 minute presentation

1. **Explain the purpose (30 seconds).** “This connects fellow onboarding, field work, evidence, staff review and reporting in one place.” State that the data is fictional and this is a prototype.
2. **Admin overview (2 minutes).** Sign in as admin. Show labeled navigation, the two fellows, block filtering, and Asha's profile/documents/volunteers. Explain the separation between staff and fellow views.
3. **Fellow home (1 minute).** In the private window, sign in as Asha. Show the single “All set” badge and clear actions. Briefly switch English/Hindi, then return to your preferred language.
4. **Documents and volunteers (2 minutes).** Open the sample document, demonstrate choosing/reviewing/uploading a harmless file, and show the two volunteer records. Add a fictional volunteer if desired; use a different sample phone number to avoid duplicate validation.
5. **Live job workflow (3 minutes).** Open “Community visit — live demo”, start it, enter actual hours, select the sample evidence image, and submit. Explain that browser-selected photos are not verified camera captures.
6. **Admin review (2 minutes).** Refresh the admin jobs view, open the submitted job, inspect its photo/hours and approve it. If the live submission is interrupted, use the pre-seeded “Volunteer orientation — awaiting review” job instead. Return to Asha's job list and refresh to show the change.
7. **Notifications (1 minute).** Show Asha's welcome notification. Optionally create an admin announcement targeting Asha with a near-term schedule; the local delivery worker runs every 15 seconds. Refresh the inbox after it is due. These are in-app notifications, not WhatsApp or email broadcasts.
8. **Reports (1–2 minutes).** Show the block dashboard and available exports. The seed includes “Community mapping — completed” so there is approved work even before the live demonstration.
9. **Optional onboarding (2 minutes).** Sign out of Asha and sign in as Ravi. Show the incomplete-profile prompt, fill the missing profile information and save. Do this last because it changes the initial onboarding state.
10. **Close with feedback.** Ask: “Which task would you use most? What was unclear? What information is missing?”

## Sample upload

Use `/private/tmp/ngo-demo-20261029/sample-evidence.jpg` for both the document and job-photo demonstration. It is visibly labeled as fictional demo evidence. Never upload real identity or banking documents during the presentation.

## Avoid promising

- Public hosting, app-store distribution, offline sync or WhatsApp delivery.
- Real email delivery: this local demo writes verification/reset messages to the server console.
- Government document verification or verified camera provenance on web.
- Production readiness for real personal data: consent policy, key custody and recovery approval remain open.

## Restart this demo if needed

Run these in two separate terminals. Do not start another copy while the current servers are running.

```sh
/Users/chaitanyasahu/ngo_app/backend/.venv/bin/python /private/tmp/ngo-demo-20261029/demo.py serve
```

```sh
/Users/chaitanyasahu/ngo_app/backend/.venv/bin/python -u /private/tmp/ngo-demo-20261029/demo.py worker
```

The temporary demo directory can be cleared by the operating system. Do not use it for long-term records. Seeding does not reset changed job statuses; if you need another rehearsal, create a fresh job in the admin UI.

## Checks performed

Frontend HTTP 200; API readiness 200; all three logins succeeded. Admin fellow list, dashboard and jobs endpoints succeeded. Asha's profile, jobs, documents, volunteers and notification inbox succeeded. The browser automation attachment was unavailable, so this run did not re-verify the UI visually.
