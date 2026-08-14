export const STATUS_SHOOTING: string = '拍摄中';
export const STATUS_FINISHED: string = '冲洗完';

@Observed
export class Roll {
  id: string = '';
  name: string = '';
  type: string = '彩色负片';
  date: string = '';
  place: string = '';
  camera: string = '';
  lens: string = '';
  note: string = '';
  lab: string = '';
  developedDate: string = '';
  scanner: string = '';
  status: string = STATUS_SHOOTING;
  photos: string[] = [];
  cover: string = '';
  updatedAt: number = 0;

  static create(): Roll {
    const roll = new Roll();
    roll.id = `${Date.now()}`;
    roll.updatedAt = Date.now();
    return roll;
  }

  static clone(source: Roll): Roll {
    const roll = new Roll();
    roll.id = source.id;
    roll.name = source.name;
    roll.type = source.type;
    roll.date = source.date;
    roll.place = source.place;
    roll.camera = source.camera;
    roll.lens = source.lens;
    roll.note = source.note;
    roll.lab = source.lab;
    roll.developedDate = source.developedDate;
    roll.scanner = source.scanner;
    roll.status = source.status;
    roll.photos = [...source.photos];
    roll.cover = source.cover;
    roll.updatedAt = source.updatedAt;
    return roll;
  }

  static from(value: Record<string, Object>): Roll {
    const roll = new Roll();
    roll.id = `${value['id'] ?? Date.now()}`;
    roll.name = `${value['name'] ?? ''}`;
    roll.type = `${value['type'] ?? '彩色负片'}`;
    roll.date = `${value['date'] ?? ''}`;
    roll.place = `${value['place'] ?? ''}`;
    roll.camera = `${value['camera'] ?? ''}`;
    roll.lens = `${value['lens'] ?? ''}`;
    roll.note = `${value['note'] ?? ''}`;
    roll.lab = `${value['lab'] ?? ''}`;
    roll.developedDate = `${value['developedDate'] ?? ''}`;
    roll.scanner = `${value['scanner'] ?? ''}`;
    roll.status = `${value['status'] ?? STATUS_SHOOTING}`;
    const photos = value['photos'];
    roll.photos = Array.isArray(photos) ? photos.map((item: Object) => `${item}`) : [];
    roll.cover = `${value['cover'] ?? ''}`;
    const updatedAt = value['updatedAt'];
    roll.updatedAt = typeof updatedAt === 'number' ? updatedAt : Date.now();
    return roll;
  }
}

export const FILM_TYPES: string[] = ['彩色负片', '黑白负片', '反转片', '电影卷'];
export const CAMERA_PRESETS: string[] = [
  'Leica M6', 'Nikon FM2', 'Canon AE-1 Program', 'Olympus OM-1', 'Pentax K1000',
  'Contax T2', 'Fujifilm Klasse W', 'Ricoh GR1', 'Minolta X-700', 'Hasselblad 500C/M'
];
export const LENS_PRESETS: string[] = [
  '50mm f/1.8', '50mm f/1.4', '35mm f/2', '35mm f/1.4', '28mm f/2.8',
  '24mm f/2.8', '85mm f/1.8', '90mm f/2', '105mm f/2.5', '40mm f/2'
];

export class FilmPreset {
  name: string = '';
  type: string = '';
  coverIndex: number = 0;

  constructor(name: string, type: string, coverIndex: number) {
    this.name = name;
    this.type = type;
    this.coverIndex = coverIndex;
  }
}

export const FILM_PRESETS: FilmPreset[] = [
  new FilmPreset('Kodak Portra 400', '彩色负片', 0),
  new FilmPreset('Fujifilm 400H', '彩色负片', 1),
  new FilmPreset('Ilford HP5 Plus', '黑白负片', 2),
  new FilmPreset('Kodak Vision3 500T', '电影卷', 3),
  new FilmPreset('Kodak Ektachrome E100', '反转片', 4),
  new FilmPreset('Lomography Purple', '彩色负片', 5),
  new FilmPreset('Cinestill 800T', '电影卷', 6),
  new FilmPreset('Fujifilm Provia 100F', '反转片', 7),
  new FilmPreset('Kodak Gold 200', '彩色负片', 8),
  new FilmPreset('Ilford XP2 Super', '黑白负片', 9)
];

export function presetCover(index: number): string {
  return `preset:${index}`;
}

export function coverPresetIndex(value: string): number {
  if (!value.startsWith('preset:')) {
    return -1;
  }
  const parsed = Number(value.substring(7));
  return Number.isInteger(parsed) && parsed >= 0 && parsed <= 9 ? parsed : -1;
}
