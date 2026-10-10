--!strict
-- What this build ships. Rings past releasedTiers stay built but locked: the
-- gate that would open the next one says it's coming in a later update, and
-- the daily wheel never gives freaks from past it. Raise it as rings are
-- finished (5 at launch; 3 for the first private playtest).

return {
	releasedTiers = 5,
}
