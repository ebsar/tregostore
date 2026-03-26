import { createApp } from "vue";
import App from "./App.vue";
import router from "./router";
import "../static/style.css";

createApp(App).use(router).mount("#app");
