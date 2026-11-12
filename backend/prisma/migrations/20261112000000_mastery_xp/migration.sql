CREATE TABLE "MasteryXp" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "userId" TEXT NOT NULL,
    "fluencyXp" INTEGER NOT NULL DEFAULT 0,
    "lexicalXp" INTEGER NOT NULL DEFAULT 0,
    "acousticXp" INTEGER NOT NULL DEFAULT 0,
    "interactionXp" INTEGER NOT NULL DEFAULT 0,
    "totalXp" INTEGER NOT NULL DEFAULT 0,
    "level" INTEGER NOT NULL DEFAULT 1,
    "rankTitle" TEXT NOT NULL DEFAULT 'Apprentice',
    "freezeTokens" INTEGER NOT NULL DEFAULT 2,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "MasteryXp_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "MasteryXp_userId_key" ON "MasteryXp"("userId");
