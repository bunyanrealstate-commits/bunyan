package com.bunyan.english;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(LocalLlmPlugin.class);
        registerPlugin(HearPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
