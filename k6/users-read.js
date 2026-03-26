import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    vus: 1,
    iterations: 10,
};

export default function () {
    const baseUrl = __ENV.BASE_URL || 'http://localhost:19090';
    const response = http.get(`${baseUrl}/api/users/1`);

    check(response, {
        'status が 200': (r) => r.status === 200,
    });

    sleep(1);
}