import express, { type Request, type Response } from 'express';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import { pino } from 'pino';
import { pinoHttp } from 'pino-http';

const logger = pino();
const app = express();
const port = Number(process.env.PORT) || 4000;

app.use(helmet());
app.use(express.json());
app.use(cookieParser());
app.use(pinoHttp({ logger }));

app.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({ status: 'ok' });
});

app.listen(port, () => {
  logger.info(`Server listening on port ${port}`);
});