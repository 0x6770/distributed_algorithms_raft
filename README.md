# Raft

## Getting Started

### Install dependencies

Before you do anything...
run

```bash
mix deps.get
```

## Debugging

Debugging options are listed in `Makefile`. To use debugging option, add them to `DEBUG_OPTION` variable in `Makefile:15`

Debugging level by default is 0, can also be adjusted in `Makefile:17`.

## Branch Structure

We have created different branches for you to play around with different tests and configurations
instructions on how perform the tests are documented in this section

### main

This branch is used to demonstrate that when give sufficient time, client requests will eventually be replicated on each server.
To perform this test

```bash
git checkout main
make
```

You can optionally use "verify_databases.sh" after main program shutting down to verify consistency of databases.

### appendEntryTest

This branch is used to demonstrate the appendEntryTest mentioned in the report.
To perform this test

```bash
git checkout appendEntryTest
bash test_appendEntry.sh
```

### leader-election-only

This branch is used to demonstrate the leader-election process. Servers are intensionally put to sleep so that leadership competition is more aggressive.

```bash
git checkout leader-election-only
make
```
