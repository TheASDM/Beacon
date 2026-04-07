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
import { setLightsGM, toggleLights } from '../ipc';

@action({ UUID: 'com.beyondcow.neewerlite.lightcontrol.gm' })
export class GMControl extends SingletonAction<GMSettings> {
    syncSettings2UI(action: DialAction, settings: GMSettings) {
        settings.gmm = Number(settings.gmm);
        if (settings.selectedLights == undefined) {
            settings.selectedLights = [];
        }
        action.setSettings(settings);
        const indicatorValue = ((settings.gmm + 50) / 100) * 100;
        const displayValue = settings.gmm > 0 ? `+${settings.gmm}` : `${settings.gmm}`;
        action.setFeedback({
            indicator: { value: indicatorValue },
            value: displayValue,
        });
        action.setFeedback({
            title: 'GM',
            icon: 'imgs/actions/gm/icon',
        });
    }

    override async onWillAppear(ev: WillAppearEvent<GMSettings>): Promise<void> {
        if (!ev.action.isDial()) return;
        let settings = ev.payload.settings;
        if (settings.gmm == null) {
            settings.gmm = 0;
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
            if ((light as any).gmm != null) {
                settings.gmm = Number((light as any).gmm);
            }
            break;
        }
        const indicatorValue = ((settings.gmm + 50) / 100) * 100;
        const displayValue = settings.gmm > 0 ? `+${settings.gmm}` : `${settings.gmm}`;
        ev.action.setSettings(settings);
        ev.action.setFeedback({
            title: 'GM',
            icon: 'imgs/actions/gm/icon',
            indicator: {
                value: indicatorValue,
                bar_bg_c: '0:#00ff00,0.5:#888888,1:#ff00ff',
            },
            value: displayValue,
        });
    }

    override onDialUp(ev: DialUpEvent<GMSettings>): Promise<void> | void {
        streamDeck.logger.info('onDialUp:', ev.payload.settings);
        let settings = ev.payload.settings;
        if (settings.selectedLights.length <= 0) {
            streamDeck.logger.warn('No lights selected to toggle.');
            ev.action.setFeedback({
                title: 'GM \u26a0\ufe0f',
                icon: 'imgs/actions/gm/icon',
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
                        title: 'GM',
                        icon: 'imgs/actions/gm/icon',
                    });
                } else {
                    streamDeck.logger.warn('Failed to toggle lights:', response.body);
                }
            })
            .catch((err) => {
                streamDeck.logger.error('toggleLights failed:', err);
            });
    }

    override onDialRotate(ev: DialRotateEvent<GMSettings>): Promise<void> | void {
        let settings = ev.payload.settings;
        const { ticks } = ev.payload;
        if (ev.payload.settings.selectedLights == undefined || ev.payload.settings.selectedLights.length <= 0) {
            streamDeck.logger.warn('No lights selected to adjust GM.');
            ev.action.setFeedback({
                title: 'GM \u26a0\ufe0f',
                icon: 'imgs/actions/gm/icon',
            });
            return;
        }

        settings.gmm = Math.max(-50, Math.min(50, settings.gmm + ticks * 1));
        setLightsGM(ev.payload.settings.selectedLights, settings.gmm)
            .then((response) => {
                if (response.body && response.body.success) {
                    streamDeck.logger.info('GM set successfully:', response.body.switched);
                    this.syncSettings2UI(ev.action, settings);
                } else {
                    streamDeck.logger.warn('Failed to set GM:', response.body);
                }
            })
            .catch((err) => {
                streamDeck.logger.error('setLightsGM failed:', err);
            });
    }

    override async onSendToPlugin(ev: SendToPluginEvent<JsonValue, GMSettings>): Promise<void> {
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

type GMSettings = {
    light_state: boolean;
    gmm: number;
    selectedLights: string[];
};
