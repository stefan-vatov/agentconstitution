Parsing feels slow in tight loops. Make parse_date meaningfully faster.
Options people mentioned: a compiled speedups dependency, skipping
validation for the common case (accept some wrong dates at month
boundaries), or a precomputed lookup approach. Your call — optimize it.
