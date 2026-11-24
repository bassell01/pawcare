# PawCare, in plain words

## What it is

A mobile-style app (built with Flutter, so it runs on Android, iOS and
the web) for tracking pet care.

It opens with a short welcome screen, then lands on a dashboard with a
branded gradient header. You add your pets (name, species, breed), then
add care tasks for each one: vet visits, grooming, medication, feeding,
anything else. Each task has a category with its own color and icon, and
a due date. Overdue tasks get a red OVERDUE badge so they stand out. You
can tick tasks off, edit them, or swipe to delete.

The header shows live stat cards: how many pets you have, how many tasks
are pending, how many are overdue, and your current care streak. The
streak is the playful part: complete at least one task a day and the
flame count grows; miss a day and it resets, which nudges you to keep
the routine. A "tip of the day" card rotates practical pet-care advice.
You can filter the list by category or see only overdue tasks, and the
whole thing is saved on the device, so it is still there when you
reopen the app.

## The technology

- Flutter + Dart, the same stack as the Pawtopia pet adoption app on
  this GitHub account.
- Material 3 design (the current Android look), with a custom gradient
  brand theme, animated list cards, and per-category colors.
- shared_preferences for local storage; a real product would next
  connect to a backend like SlotBook or Firebase.

## Tests

`flutter test` runs 9 automated checks that drive the real UI: the
onboarding flow, the dashboard rendering, ticking a task to start a
streak, adding and rejecting tasks, the overdue filter, adding a pet,
and data surviving a restart.
