import streamDeck, {
    action,
    SingletonAction,
    WillAppearEvent,
    type JsonValue,
    type KeyDownEvent,
    type SendToPluginEvent,
} from '@elgato/streamdeck';
import type { GlobalSettings, Light } from '../sdpi';
import { cycleFX } from '../ipc';

@action({ UUID: 'com.beyondcow.neewerlite.lightcontrol.fx.cycle' })
export class FXCycleControl extends SingletonAction<FXCycleSettings> {
    override async onWillAppear(ev: WillAppearEvent<FXCycleSettings>): Promise<void> {
        let settings = ev.payload.settings;
        if (settings.selectedLights == undefined) {
            settings.selectedLights = [];
        }
        ev.action.setSettings(settings);

        let { lights = [] } = await streamDeck.settings.getGlobalSettings<GlobalSettings>();
        let title = 'FX \u25b6';
        for (const light of lights) {
            if (light.state == -1) {
                continue;
            }
            if ((light as any).mode === 'sce' && (light as any).fxName) {
                title = (light as any).fxName;
                settings.fxName = title;
                ev.action.setSettings(settings);
            }
            break;
        }
        ev.action.setTitle(title);
    }

    override onKeyDown(ev: KeyDownEvent<FXCycleSettings>): Promise<void> | void {
        let settings = ev.payload.settings;
        if (settings.selectedLights.length <= 0) {
            streamDeck.logger.warn('No lights selected.');
            return;
        }
        cycleFX(settings.selectedLights, 1)
            .then((response) => {
                if (response.body && response.body.success) {
                    streamDeck.logger.info('FX cycled successfully:', response.body.switched);
                    const fxName = (response.body as any).fxName || settings.fxName || 'FX \u25b6';
                    settings.fxName = fxName;
                    ev.action.setSettings(settings);
                    ev.action.setTitle(fxName);
                } else {
                    streamDeck.logger.warn('Failed to cycle FX:', response.body);
                }
            })
            .catch((err) => {
                streamDeck.logger.error('cycleFX failed:', err);
            });
    }

    override async onSendToPlugin(ev: SendToPluginEvent<JsonValue, FXCycleSettings>): Promise<void> {
        streamDeck.logger.debug('Received message from property inspector:', ev);
        if (ev.payload instanceof Object && 'event' in ev.payload && ev.payload.event === 'deviceList') {
            let { lights = [] } = await streamDeck.settings.getGlobalSettings<GlobalSettings>();
            let ui_lights = [];
            for (const light of lights) {
                if (light.supportRGB) {
                    ui_lights.push({
                        label: light.name,
                        value: light.id,
                        disabled: light.state == -1,
                    });
                }
            }
            streamDeck.logger.debug('Sending device list to property inspector:', ui_lights);
            streamDeck.ui.current?.sendToPropertyInspector({
                event: 'deviceList',
                items: ui_lights,
            });
        }
    }
}

type FXCycleSettings = {
    selectedLights: string[];
    fxName: string;
};
