-- Streak aggregation filters each source by user and activity timestamp.
CREATE INDEX "ReviewSchedule_userId_lastReviewedAt_idx" ON "ReviewSchedule"("userId", "lastReviewedAt");

CREATE INDEX "SpeakingSession_userId_completedAt_idx" ON "SpeakingSession"("userId", "completedAt");

CREATE INDEX "Conversation_userId_finishedAt_idx" ON "Conversation"("userId", "finishedAt");

CREATE INDEX "IeltsAttempt_userId_finishedAt_idx" ON "IeltsAttempt"("userId", "finishedAt");
