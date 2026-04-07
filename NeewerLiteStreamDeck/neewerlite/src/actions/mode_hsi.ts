import streamDeck, {
    action,
    SingletonAction,
    WillAppearEvent,
    type JsonValue,
    type KeyDownEvent,
    type SendToPluginEvent,
} from '@elgato/streamdeck';
import type { GlobalSettings, Light } from '../sdpi';
import { setLightsMode } from '../ipc';

@action({ UUID: 'com.beyondcow.neewerlite.lightcontrol.mode.hsi' })
export class ModeHSIControl extends SingletonAction<ModeSettings> {
    override async onWillAppear(ev: WillAppearEvent<ModeSettings>): Promise<void> {
        let settings = ev.payload.settings;
        if (settings.selectedLights == undefined) {
            settings.selectedLights = [];
        }
        ev.action.setSettings(settings);

        let { lights = [] } = await streamDeck.settings.getGlobalSettings<GlobalSettings>();
        let isHSI = false;
        for (const light of lights) {
            if (light.state == -1) {
                continue;
            }
            if ((light as any).mode === 'hsi') {
                isHSI = true;
            }
            break;
        }
        ev.action.setTitle(isHSI ? 'HSI \u2713' : 'HSI');
    }

    override onKeyDown(ev: KeyDownEvent<ModeSettings>): Promise<void> | void {
        let settings = ev.payload.settings;
        if (settings.selectedLights.length <= 0) {
            streamDeck.logger.warn('No lights selected.');
            return;
        }
        setLightsMode(settings.selectedLights, 'hsi')
            .then((response) => {
                if (response.body && response.body.success) {
                    streamDeck.logger.info('Mode set to HSI successfully:', response.body.switched);
                    ev.action.setTitle('HSI \u2713');
                } else {
                    streamDeck.logger.warn('Failed to set mode to HSI:', response.body);
                }
            })
            .catch((err) => {
                streamDeck.logger.error('setLightsMode failed:', err);
            });
    }

    override async onSendToPlugin(ev: SendToPluginEvent<JsonValue, ModeSettings>): Promise<void> {
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

type ModeSettings = {
    selectedLights: string[];
};
