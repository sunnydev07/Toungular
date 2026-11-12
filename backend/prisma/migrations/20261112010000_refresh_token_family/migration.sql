-- A refresh-token family links one rotation chain so a replayed token can
-- revoke every descendant instead of only itself.
ALTER TABLE "RefreshToken" ADD COLUMN "familyId" TEXT;

CREATE INDEX "RefreshToken_userId_familyId_idx" ON "RefreshToken"("userId", "familyId");
