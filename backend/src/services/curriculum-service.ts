import type { PrismaClient } from '@prisma/client';

import type { LessonProgress, Roadmap } from '../contracts.js';
import { AppError } from '../lib/http.js';

export class CurriculumService {
  public constructor(private readonly database: PrismaClient) {}

  public async getRoadmap(userId: string): Promise<Roadmap> {
    const courses = await this.database.course.findMany({
      orderBy: { position: 'asc' },
      include: {
        lessons: {
          orderBy: { position: 'asc' },
          include: { progress: { where: { userId }, select: { completedAt: true } } },
        },
      },
    });
    const mappedCourses = courses.map((course) => ({
      id: course.id,
      title: course.title,
      description: course.description,
      level: course.level,
      position: course.position,
      lessons: course.lessons.map((lesson) => ({
        id: lesson.id,
        title: lesson.title,
        summary: lesson.summary,
        durationMin: lesson.durationMin,
        position: lesson.position,
        completedAt: lesson.progress[0]?.completedAt ?? null,
      })),
    }));
    const completedLessonCount = mappedCourses.reduce(
      (total, course) => total + course.lessons.filter((lesson) => lesson.completedAt !== null).length,
      0,
    );
    return { courses: mappedCourses, completedLessonCount };
  }

  public async getLesson(userId: string, lessonId: string) {
    const lesson = await this.database.lesson.findUnique({
      where: { id: lessonId },
      include: {
        course: { select: { id: true, title: true } },
        progress: { where: { userId }, select: { completedAt: true } },
      },
    });
    if (!lesson) {
      throw new AppError(404, 'LESSON_NOT_FOUND', 'The requested lesson was not found.');
    }
    return {
      id: lesson.id,
      course: lesson.course,
      title: lesson.title,
      summary: lesson.summary,
      content: lesson.content,
      durationMin: lesson.durationMin,
      position: lesson.position,
      completedAt: lesson.progress[0]?.completedAt ?? null,
    };
  }

  public async completeLesson(userId: string, lessonId: string): Promise<LessonProgress> {
    const lesson = await this.database.lesson.findUnique({ where: { id: lessonId }, select: { id: true } });
    if (!lesson) {
      throw new AppError(404, 'LESSON_NOT_FOUND', 'The requested lesson was not found.');
    }
    const completedAt = new Date();
    const progress = await this.database.lessonProgress.upsert({
      where: { userId_lessonId: { userId, lessonId } },
      update: { completedAt },
      create: { userId, lessonId, completedAt },
    });
    return { lessonId: progress.lessonId, completedAt: progress.completedAt };
  }
}
