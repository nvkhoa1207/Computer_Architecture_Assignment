#include <iostream>
#include <fstream>
#include <cmath>
#include <iomanip>
#include <string>

using namespace std;

#define MAX_SIZE 500

// Tính autocorrelation của signal
void computeAutocorrelation(double signal[MAX_SIZE], double autocorr[MAX_SIZE], int N) {
    // TODO
    for (int k= 0; k < N; k++){
        double sum = 0.0;
        for (int n = k; n < N; n++){
            sum += signal[n] * signal[n - k];
        }
        autocorr[k] = sum / N;
    }
}

// Hàm tính crosscorrelation giữa desired signal và input signal
void computeCrosscorrelation(double desired[MAX_SIZE], double input[MAX_SIZE], double crosscorr[MAX_SIZE], int N) {
    // TODO
    for (int k = 0; k < N; k++){
        double sum = 0.0;
        for (int n = k; n < N; n++){
            sum += desired[n] * input[n - k];
        }
        crosscorr[k] = sum / N;
    }
}

// Hàm tạo ma trận Toeplitz từ autocorrelation
void createToeplitzMatrix(double autocorr[MAX_SIZE], double R[MAX_SIZE][MAX_SIZE], int N) {
    // TODO
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            int diff = abs(i - j);    // |i - j|
            R[i][j] = autocorr[diff]; // γxx(|i - j|)
        }
    }
}

// Gauss elimination
void solveLinearSystem(double A[MAX_SIZE][MAX_SIZE], double b[MAX_SIZE], double x[MAX_SIZE], int N) {
    // TODO
    double temp[MAX_SIZE][MAX_SIZE + 1];

    //[A|b]
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j)
            temp[i][j] = A[i][j];
        temp[i][N] = b[i];
    }

    for (int i = 0; i < N; ++i) {
        double pivot = temp[i][i];
        // if (fabs(pivot) < 1e-12)
        //     throw runtime_error("Ma trận suy biến (không có nghiệm duy nhất)");

        for (int j = i; j <= N; ++j)
            temp[i][j] /= pivot;

        for (int k = 0; k < N; ++k) {
            if (k == i) continue;
            double factor = temp[k][i];
            for (int j = i; j <= N; ++j)
                temp[k][j] -= factor * temp[i][j];
        }
    }

    for (int i = 0; i < N; ++i)
        x[i] = temp[i][N];
}

// Tính hệ số Wiener
void computeWienerCoefficients(double desired[MAX_SIZE], double input[MAX_SIZE], int N, double coefficients[MAX_SIZE]) {
    double autocorr[MAX_SIZE];
    double crosscorr[MAX_SIZE];
    double R[MAX_SIZE][MAX_SIZE];

    computeAutocorrelation(input, autocorr, N);
    computeCrosscorrelation(desired, input, crosscorr, N);
    createToeplitzMatrix(autocorr, R, N);
    solveLinearSystem(R, crosscorr, coefficients, N);
}

// Áp dụng Wiener filter
void applyWienerFilter(double input[MAX_SIZE], double coefficients[MAX_SIZE], double output[MAX_SIZE], int N) {
    // TODO
    for (int n = 0; n < N; ++n) {
        double sum = 0.0;
        for (int k = 0; k < N; ++k) {
            if (n - k >= 0)
                sum += coefficients[k] * input[n - k];
        }
        output[n] = sum;
    }
}

// Tính MMSE
double computeMMSE(double desired[MAX_SIZE], double output[MAX_SIZE], int N) {
    // TODO
    double sum = 0.0;
    for (int i = 0; i < N; ++i) {
        double error = desired[i] - output[i];
        sum += error * error;  // (d - y)^2
    }
    return sum / N; 
}

// Đọc file
int readSignalFromFile(const string &filename, double signal[MAX_SIZE]) {
    ifstream file(filename);
    if (!file.is_open()) throw runtime_error("Cannot open file: " + filename);

    int count = 0;
    double value = 0;
    // TODO
    while (file >> value) {
        signal[count] = value;
        count++;
        if (count >= MAX_SIZE) break;  
    }

    file.close();
    return count;
}

// Ghi file
void writeOutputToFile(const string &filename, double output[MAX_SIZE], int N, double mmse) {
    ofstream file(filename);
    if (!file.is_open())
        throw runtime_error("Cannot open output file: " + filename);

    file << fixed << setprecision(1);
    file << "Filtered output: ";
    for (int i = 0; i < N; ++i) {
        if (fabs(output[i]) < 0.05) output[i] = 0.0;
        file << output[i];
        if (i != N - 1)
            file << " ";
    }

    file << "\n";

    // MMSE line
    file << "MMSE: " << fixed << setprecision(1) << mmse;
    file.close();
}

int main()
{
    try
    {
        double desired[MAX_SIZE], input[MAX_SIZE], output[MAX_SIZE], coefficients[MAX_SIZE];

        int SIZE = readSignalFromFile("desired.txt", desired);
        int N2 = readSignalFromFile("input.txt", input);

        if (SIZE != N2)
        {
            ofstream errorFile("output.txt");
            errorFile << "Error: size not match" << endl;
            errorFile.close();
            cerr << "Error: size not match" << endl;
            return 0;
        }

        computeWienerCoefficients(desired, input, SIZE, coefficients);
        applyWienerFilter(input, coefficients, output, SIZE);
        double mmse = computeMMSE(desired, output, SIZE);
        writeOutputToFile("output.txt", output, SIZE, mmse);
        cout << "Done VO TIEN ! Check output.txt for results." << endl;
    }
    catch (const exception &e)
    {
        cerr << "Error: " << e.what() << endl;
        ofstream errorFile("output.txt");
        errorFile << e.what() << endl;
        errorFile.close();
        return 1;
    }

    return 0;
}