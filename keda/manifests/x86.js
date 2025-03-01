import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 300,
  duration: '5m',
};

const ITERATIONS = 750000;  // Fixed number of iterations for consistency

export default function () {
  const url = `http://ad3392667aef743bf98c6d3aa46d3898-1288783823.eu-west-1.elb.amazonaws.com/simulate?iterations=${ITERATIONS}`;

  const res = http.get(url);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'latency < 500ms': (r) => r.timings.duration < 500,
  });

  // Add a small sleep to prevent overwhelming the system
  sleep(0.05);
}