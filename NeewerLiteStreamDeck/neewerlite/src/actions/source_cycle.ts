import streamDeck, {
    action,
    SingletonAction,
    WillAppearEvent,
    type JsonValue,
    type KeyDownEvent,
    type SendToPluginEvent,
} from '@elgato/streamdeck';
import type { GlobalSettings, Light } from '../sdpi';
import { cycleSource } from '../ipc';

@action({ UUID: 'com.beyondcow.neewerlite.lightcontrol.source.cycle' })
export class SourceCycleControl extends SingletonAction<SourceCycleSettings> {
    override async onWillAppear(ev: WillAppearEvent<SourceCycleSettings>): Promise<void> {
        let settings = ev.payload.settings;
        if (settings.selectedLights == undefined) {
            settings.selectedLights = [];
        }
        ev.action.setSettings(settings);
        ev.action.setTitle('Source \u25b6');
    }

    override onKeyDown(ev: KeyDownEvent<SourceCycleSettings>): Promise<void> | void {
        let settings = ev.payload.settings;
        if (settings.selectedLights.length <= 0) {
            streamDeck.logger.warn('No lights selected.');
            return;
        }
        cycleSource(settings.selectedLights, 1)
            .then((response) => {
                if (response.body && response.body.success) {
                    streamDeck.logger.info('Source cycled successfully:', response.body.switched);
                    const sourceName = (response.body as any).sourceName || settings.sourceName || 'Source \u25b6';
                    settings.sourceName = sourceName;
                    ev.action.setSettings(settings);
                    ev.action.setTitle(sourceName);
                } else {
                    streamDeck.logger.warn('Failed to cycle source:', response.body);
                }
            })
            .catch((err) => {
                streamDeck.logger.error('cycleSource failed:', err);
            });
    }

    override async onSendToPlugin(ev: SendToPluginEvent<JsonValue, SourceCycleSettings>): Promise<void> {
        streamDeck.logger.debug('Received message from property inspector:', ev);
        if (ev.payload instanceof Object && 'event' in ev.payload && ev.payload.event === 'deviceList') {
            let { lights = [] } = await streamDeck.settings.getGlobalSettings<GlobalSettings>();
            let ui_lights = lights.map((light) => ({
                label: light.name,
                value: light.id,
                disabled: light.state == -1,
            }));
            streamDeck.logger.debug('Sending device list to property inspector:', ui_lights);
            streamDeck.ui.current?.sendToPropertyInspector({
                event: 'deviceList',
                items: ui_lights,
            });
        }
    }
}

type SourceCycleSettings = {
    selectedLights: string[];
    sourceName: string;
};
