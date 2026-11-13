-- Scope user-added vocabulary to its creator so private words stay private.
ALTER TABLE "VocabularyItem" ADD COLUMN "createdByUserId" TEXT;
CREATE INDEX "VocabularyItem_createdByUserId_idx" ON "VocabularyItem"("createdByUserId");
