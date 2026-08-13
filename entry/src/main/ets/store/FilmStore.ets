import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Roll } from '../model/Roll';

const STORE_NAME: string = 'film_memory';
const ROLLS_KEY: string = 'rolls';

export class FilmStore {
  static async load(context: common.UIAbilityContext): Promise<Roll[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME);
      const text = await store.get(ROLLS_KEY, '[]') as string;
      const parsed = JSON.parse(text) as Object[];
      return parsed.map((item: Object) => Roll.from(item as Record<string, Object>));
    } catch (_) {
      return [];
    }
  }

  static async save(context: common.UIAbilityContext, rolls: Roll[]): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME);
      await store.put(ROLLS_KEY, JSON.stringify(rolls));
      await store.flush();
    } catch (_) {
      // Keep the current in-memory state if the device storage is temporarily unavailable.
    }
  }
}
