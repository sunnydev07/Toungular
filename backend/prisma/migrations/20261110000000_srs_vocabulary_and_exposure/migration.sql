ALTER TABLE "Lesson" ADD COLUMN "vocabularyIds" TEXT NOT NULL DEFAULT '[]';
ALTER TABLE "VocabularyItem" ADD COLUMN "tier" INTEGER NOT NULL DEFAULT 2;
ALTER TABLE "ReviewSchedule" ADD COLUMN "easeFactor" REAL NOT NULL DEFAULT 2.5;
ALTER TABLE "ReviewSchedule" ADD COLUMN "lapses" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "ReviewSchedule" ADD COLUMN "lastRecallMode" TEXT;
ALTER TABLE "ReviewSchedule" ADD COLUMN "source" TEXT NOT NULL DEFAULT 'catalog';
ALTER TABLE "ReviewSchedule" ADD COLUMN "context" TEXT;
CREATE TABLE "ExposureProgress" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "userId" TEXT NOT NULL,
    "level" INTEGER NOT NULL,
    "sessions" INTEGER NOT NULL DEFAULT 0,
    "lastPracticedAt" DATETIME,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "ExposureProgress_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "ExposureProgress_userId_level_key" ON "ExposureProgress"("userId", "level");
