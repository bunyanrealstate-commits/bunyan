package com.bunyan.yawmi;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(MaktabatiPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
