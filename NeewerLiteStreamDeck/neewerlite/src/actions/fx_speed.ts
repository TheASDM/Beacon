import streamDeck, {
    action,
    DialAction,
    DialRotateEvent,
    DialUpEvent,
    SingletonAction,
    WillAppearEvent,
    type JsonValue,
    type SendToPluginEvent,
} from '@elgato/streamdeck';
import type { GlobalSettings, Light } from '../sdpi';
import { setFXSpeed, toggleLights } from '../ipc';

@action({ UUID: 'com.beyondcow.neewerlite.lightcontrol.fx.speed' })
export class FXSpeedControl extends SingletonAction<FXSpeedSettings> {
    syncSettings2UI(action: DialAction, settings: FXSpeedSettings) {
        settings.speed = Number(settings.speed);
        if (settings.selectedLights == undefined) {
            settings.selectedLights = [];
        }
        action.setSettings(settings);
        action.setFeedback({
            indicator: { value: settings.speed * 10 },
            value: `${settings.speed}`,
        });
        action.setFeedback({
            title: 'FX Speed',
            icon: 'imgs/actions/fx_speed/icon',
        });
    }

    override async onWillAppear(ev: WillAppearEvent<FXSpeedSettings>): Promise<void> {
        if (!ev.action.isDial()) return;
        let settings = ev.payload.settings;
        if (settings.speed == null) {
            settings.speed = 5;
        }
        if (settings.selectedLights == undefined) {
            settings.selectedLights = [];
        }
        let { lights = [] } = await streamDeck.settings.getGlobalSettings<GlobalSettings>();
        for (const light of lights) {
            if (light.state == -1) {
                continue;
            }
            settings.light_state = light.state == 1;
            break;
        }
        ev.action.setSettings(settings);
        ev.action.setFeedback({
            title: 'FX Speed',
            icon: 'imgs/actions/fx_speed/icon',
            indicator: {
                value: settings.speed * 10,
            },
            value: `${settings.speed}`,
        });
    }

    override onDialUp(ev: DialUpEvent<FXSpeedSettings>): Promise<void> | void {
        streamDeck.logger.info('onDialUp:', ev.payload.settings);
        let settings = ev.payload.settings;
        if (settings.selectedLights.length <= 0) {
            streamDeck.logger.warn('No lights selected to toggle.');
            ev.action.setFeedback({
                title: 'FX Speed \u26a0\ufe0f',
                icon: 'imgs/actions/fx_speed/icon',
            });
            return;
        }
        settings.light_state = !settings.light_state;
        toggleLights(ev.payload.settings.selectedLights, settings.light_state)
            .then((response) => {
                if (response.body && response.body.success) {
                    streamDeck.logger.info('Lights toggled successfully:', response.body.switched);
                    ev.action.setSettings(settings);
                    ev.action.setFeedback({
                        title: 'FX Speed',
                        icon: 'imgs/actions/fx_speed/icon',
                    });
                } else {
                    streamDeck.logger.warn('Failed to toggle lights:', response.body);
                }
            })
            .catch((err) => {
                streamDeck.logger.error('toggleLights failed:', err);
            });
    }

    override onDialRotate(ev: DialRotateEvent<FXSpeedSettings>): Promise<void> | void {
        let settings = ev.payload.settings;
        const { ticks } = ev.payload;
        if (ev.payload.settings.selectedLights == undefined || ev.payload.settings.selectedLights.length <= 0) {
            streamDeck.logger.warn('No lights selected to adjust FX Speed.');
            ev.action.setFeedback({
                title: 'FX Speed \u26a0\ufe0f',
                icon: 'imgs/actions/fx_speed/icon',
            });
            return;
        }

        settings.speed = Math.max(1, Math.min(10, settings.speed + ticks * 1));
        setFXSpeed(ev.payload.settings.selectedLights, settings.speed)
            .then((response) => {
                if (response.body && response.body.success) {
                    streamDeck.logger.info('FX Speed set successfully:', response.body.switched);
                    this.syncSettings2UI(ev.action, settings);
                } else {
                    streamDeck.logger.warn('Failed to set FX Speed:', response.body);
                }
            })
            .catch((err) => {
                streamDeck.logger.error('setFXSpeed failed:', err);
            });
    }

    override async onSendToPlugin(ev: SendToPluginEvent<JsonValue, FXSpeedSettings>): Promise<void> {
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

type FXSpeedSettings = {
    light_state: boolean;
    speed: number;
    selectedLights: string[];
};
