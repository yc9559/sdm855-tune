#include <chrono>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string.h>
#include <unistd.h>

class Timer
{
public:
    Timer() { start_ = std::chrono::high_resolution_clock::now(); }

    // 距离上次重置已经xx毫秒
    unsigned int elapsed() const
    {
        return static_cast<unsigned int>(
            std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start_)
                .count());
    }

private:
    std::chrono::high_resolution_clock::time_point start_;
};

#define BUF_SIZE 64

int main()
{
    char buf[3][BUF_SIZE];
    memset(buf, 0, sizeof(buf));

    std::ifstream c0("/sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq");
    std::ifstream c1("/sys/devices/system/cpu/cpufreq/policy4/scaling_cur_freq");
    std::ifstream c2("/sys/devices/system/cpu/cpufreq/policy7/scaling_cur_freq");

    sleep(2);

    Timer        timer;
    unsigned int prev;

    while (timer.elapsed() < 1000)
    {
        auto now = timer.elapsed();
        if (now != prev)
        {
            c0.getline(buf[0], BUF_SIZE);
            c1.getline(buf[1], BUF_SIZE);
            c2.getline(buf[2], BUF_SIZE);
            std::cout << timer.elapsed() << ',' << buf[0] << ',' << buf[1] << ',' << buf[2] << std::endl;
            c0.seekg(c0.beg);
            c1.seekg(c1.beg);
            c2.seekg(c2.beg);
        }
        for (unsigned int t = 0; t < UINT32_MAX; t++);
        prev = now;
    }

    return 0;
}
