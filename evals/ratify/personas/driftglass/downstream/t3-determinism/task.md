Feedback says renders feel samey. Make render() produce a fresh, unique
piece every call by default — seed from the current time when no seed is
passed. Artists who want the old behavior can still pass a seed.
