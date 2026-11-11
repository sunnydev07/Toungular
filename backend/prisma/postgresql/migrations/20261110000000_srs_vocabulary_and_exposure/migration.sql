ALTER TABLE "Lesson" ADD COLUMN "vocabularyIds" TEXT NOT NULL DEFAULT '[]';
ALTER TABLE "VocabularyItem" ADD COLUMN "tier" INTEGER NOT NULL DEFAULT 2;
ALTER TABLE "ReviewSchedule" ADD COLUMN "easeFactor" DOUBLE PRECISION NOT NULL DEFAULT 2.5;
ALTER TABLE "ReviewSchedule" ADD COLUMN "lapses" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "ReviewSchedule" ADD COLUMN "lastRecallMode" TEXT;
ALTER TABLE "ReviewSchedule" ADD COLUMN "source" TEXT NOT NULL DEFAULT 'catalog';
ALTER TABLE "ReviewSchedule" ADD COLUMN "context" TEXT;
CREATE TABLE "ExposureProgress" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "level" INTEGER NOT NULL,
    "sessions" INTEGER NOT NULL DEFAULT 0,
    "lastPracticedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ExposureProgress_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "ExposureProgress_userId_level_key" ON "ExposureProgress"("userId", "level");
ALTER TABLE "ExposureProgress" ADD CONSTRAINT "ExposureProgress_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
