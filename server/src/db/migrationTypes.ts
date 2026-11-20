export interface MigrationRecord {
  id: number;
  name: string;
  checksum: string;
  appliedAt: string;
}

export interface MigrationFile {
  filename: string;
  number: number;
  name: string;
  sql: string;
  checksum: string;
}

export interface MigrationStatus {
  total: number;
  applied: MigrationRecord[];
  pending: MigrationFile[];
  drift: boolean;
}