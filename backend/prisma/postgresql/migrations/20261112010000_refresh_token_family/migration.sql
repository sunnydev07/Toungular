ALTER TABLE "RefreshToken" ADD COLUMN "familyId" TEXT;

CREATE INDEX "RefreshToken_userId_familyId_idx" ON "RefreshToken"("userId", "familyId");
