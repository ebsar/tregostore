import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '15s', target: 20 },
    { duration: '15s', target: 50 },
    { duration: '15s', target: 100 },
    { duration: '15s', target: 200 },
    { duration: '15s', target: 300 },
    { duration: '20s', target: 300 },
    { duration: '10s', target: 0 },
  ],
};

export default function () {
  const res = http.get('https://tregos.store/api/products');

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response under 1s': (r) => r.timings.duration < 1000,
  });

  sleep(1);
}