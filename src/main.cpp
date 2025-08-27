#include <QApplication>
#include <QWidget>
#include <QPushButton>
#include <QLineEdit>
#include <QComboBox>
#include <QVBoxLayout>
#include <QTextEdit>
#include <QProcess>

class MainWindow : public QWidget {
public:
    MainWindow() {
        auto *layout = new QVBoxLayout(this);
        combo = new QComboBox(this);
        combo->addItem("winget");
        combo->addItem("choco");
        combo->addItem("npm");
        layout->addWidget(combo);

        input = new QLineEdit(this);
        input->setPlaceholderText("Package name");
        layout->addWidget(input);

        output = new QTextEdit(this);
        output->setReadOnly(true);
        layout->addWidget(output);

        auto *button = new QPushButton("Install", this);
        layout->addWidget(button);

        QObject::connect(button, &QPushButton::clicked, [this]() { runCommand(); });
    }

private:
    void runCommand() {
        QString pkg = input->text();
        if (pkg.isEmpty()) return;

        QString manager = combo->currentText();
        QStringList args;
        if (manager == "winget") {
            args << "install" << pkg;
        } else if (manager == "choco") {
            args << "install" << pkg << "-y";
        } else if (manager == "npm") {
            args << "install" << "-g" << pkg;
        }

        QProcess proc;
        proc.start(manager, args);
        proc.waitForFinished();
        output->append(proc.readAllStandardOutput());
        output->append(proc.readAllStandardError());
    }

    QComboBox *combo;
    QLineEdit *input;
    QTextEdit *output;
};

int main(int argc, char **argv) {
    QApplication app(argc, argv);
    MainWindow w;
    w.show();
    return app.exec();
}
